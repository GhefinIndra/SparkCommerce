// models/Token.js
const { DataTypes } = require("sequelize");
const sequelize = require("../config/sequelize");
const { encrypt, decrypt } = require("../utils/encryption");
const Shop = require("./Shop");

const Token = sequelize.define(
  "Token",
  {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true,
    },

    //  TAMBAHAN: Link ke user yang login
    // models/Token.js - bagian user_id saja yang perlu diubah
    user_id: {
      type: DataTypes.INTEGER,
      allowNull: true, // Ubah jadi true untuk backward compatibility
      references: {
        model: "users",
        key: "id",
      },
    },

    // Platform identifier (tiktok, shopee, tokopedia, etc)
    platform: {
      type: DataTypes.ENUM('tiktok', 'shopee', 'tokopedia', 'lazada', 'bukalapak'),
      allowNull: false,
      defaultValue: 'tiktok',
    },

    // OAuth Fields
    access_token: {
      type: DataTypes.TEXT,
      allowNull: false,
      get() {
        const raw = this.getDataValue("access_token");
        return decrypt(raw);
      },
      set(value) {
        this.setDataValue("access_token", encrypt(value));
      },
    },
    refresh_token: {
      type: DataTypes.TEXT,
      allowNull: true,
      get() {
        const raw = this.getDataValue("refresh_token");
        return decrypt(raw);
      },
      set(value) {
        this.setDataValue("refresh_token", encrypt(value));
      },
    },
    open_id: {
      type: DataTypes.STRING(255),
      allowNull: false,
    },

    // Shop reference (FK -> shops.id)
    shop_id: {
      type: DataTypes.INTEGER,
      allowNull: true,
      references: {
        model: "shops",
        key: "id",
      },
    },
    granted_scopes: {
      type: DataTypes.TEXT,
      allowNull: true,
      get() {
        const rawValue = this.getDataValue("granted_scopes");
        return rawValue ? JSON.parse(rawValue) : [];
      },
      set(value) {
        this.setDataValue("granted_scopes", JSON.stringify(value || []));
      },
    },
    status: {
      type: DataTypes.ENUM("pending", "active", "inactive"),
      defaultValue: "pending",
    },

    // Timestamps
    expire_at: {
      type: DataTypes.DATE,
      allowNull: true,
    },

    // Virtual fields from Shop (for backward compatibility in controllers)
    shop_name: {
      type: DataTypes.VIRTUAL,
      get() {
        return this.shop ? this.shop.shop_name : null;
      },
    },
    shop_code: {
      type: DataTypes.VIRTUAL,
      get() {
        return this.shop ? this.shop.shop_code : null;
      },
    },
    shop_cipher: {
      type: DataTypes.VIRTUAL,
      get() {
        return this.shop ? this.shop.shop_cipher : null;
      },
    },
    shop_region: {
      type: DataTypes.VIRTUAL,
      get() {
        return this.shop ? this.shop.shop_region : null;
      },
    },
    seller_id: {
      type: DataTypes.VIRTUAL,
      get() {
        return this.shop ? this.shop.seller_id : null;
      },
    },
    seller_name: {
      type: DataTypes.VIRTUAL,
      get() {
        return this.shop ? this.shop.seller_name : null;
      },
    },
    seller_type: {
      type: DataTypes.VIRTUAL,
      get() {
        return this.shop ? this.shop.seller_type : null;
      },
    },
    region: {
      type: DataTypes.VIRTUAL,
      get() {
        return this.shop ? this.shop.region : null;
      },
    },
    marketplace_shop_id: {
      type: DataTypes.VIRTUAL,
      get() {
        return this.shop ? this.shop.marketplace_shop_id : null;
      },
    },
  },
  {
    tableName: "tokens",
    timestamps: true,
    createdAt: "created_at",
    updatedAt: "updated_at",

    indexes: [
      {
        unique: true,
        fields: ["platform", "open_id"], // Composite unique: platform + open_id
        name: "platform_open_id_unique",
      },
      {
        fields: ["user_id"],
        name: "user_id_index",
      },
      {
        fields: ["platform"],
        name: "platform_index",
      },
      {
        fields: ["shop_id", "platform"],
        name: "shop_id_platform_index",
      },
    ],
    defaultScope: {
      include: [
        {
          model: Shop,
          as: "shop",
          required: false,
        },
      ],
    },
  },
);

Token.belongsTo(Shop, { foreignKey: "shop_id", as: "shop" });

//  UPDATED: Static methods dengan user_id filter
Token.findByOpenId = function (openId, userId = null) {
  const where = { open_id: openId };
  if (userId) where.user_id = userId;

  return this.findOne({ where });
};

Token.findByShopId = async function (shopId, userId = null, platform = null) {
  if (shopId === null || shopId === undefined) return null;

  let shopRecord = null;
  const shopIdString = shopId.toString();

  if (platform) {
    shopRecord = await Shop.findOne({
      where: {
        marketplace_platform: platform,
        marketplace_shop_id: shopIdString,
      },
    });
  }

  if (!shopRecord) {
    const parsedId = Number.parseInt(shopId, 10);
    if (!Number.isNaN(parsedId)) {
      shopRecord = await Shop.findByPk(parsedId);
    }
  }

  if (!shopRecord && !platform) {
    shopRecord = await Shop.findOne({
      where: { marketplace_shop_id: shopIdString },
    });
  }

  if (!shopRecord) return null;

  const where = { shop_id: shopRecord.id };
  if (userId) where.user_id = userId;
  if (platform) where.platform = platform;

  return this.findOne({ where });
};

Token.getActiveTokens = function (userId = null) {
  const where = { status: "active" };
  if (userId) where.user_id = userId;

  return this.findAll({
    where,
    order: [["updated_at", "DESC"]],
  });
};

//  NEW: Method untuk mendapatkan token berdasarkan user
Token.findUserTokens = function (userId) {
  return this.findAll({
    where: {
      user_id: userId,
      status: "active",
    },
    order: [["updated_at", "DESC"]],
  });
};

Token.createUserToken = function (tokenData, userId) {
  return this.create({
    ...tokenData,
    user_id: userId,
  });
};

Token.getUnclaimedShops = async function () {
  const { Op } = require("sequelize");

  try {
    // Ambil semua toko yang aktif dan punya shop_id
    // TIDAK perlu filter berdasarkan UserShop karena 1 toko bisa multiple users
    return this.findAll({
      where: {
        status: "active",
        shop_id: { [Op.ne]: null },
      },
      order: [["updated_at", "DESC"]],
    });
  } catch (error) {
    console.error(" Error in getUnclaimedShops:", error);
    throw error;
  }
};

module.exports = Token;
