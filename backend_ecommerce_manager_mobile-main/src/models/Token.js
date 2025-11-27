// models/Token.js
const { DataTypes } = require("sequelize");
const sequelize = require("../config/sequelize");

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
      comment: 'E-commerce platform identifier',
    },

    // OAuth Fields
    access_token: {
      type: DataTypes.TEXT,
      allowNull: false,
    },
    refresh_token: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    open_id: {
      type: DataTypes.STRING(255),
      allowNull: false,
      comment: 'Unique identifier from platform (can be shop_id for some platforms)',
    },

    // Shop Information
    shop_id: {
      type: DataTypes.STRING(255),
      allowNull: true,
    },
    shop_code: {
      type: DataTypes.STRING(255),
      allowNull: true,
    },
    shop_name: {
      type: DataTypes.STRING(500),
      allowNull: true,
    },
    shop_cipher: {
      type: DataTypes.STRING(255),
      allowNull: true,
    },
    shop_region: {
      type: DataTypes.STRING(100),
      allowNull: true,
    },

    // Seller Information
    seller_id: {
      type: DataTypes.STRING(255),
      allowNull: true,
    },
    seller_name: {
      type: DataTypes.STRING(500),
      allowNull: true,
    },
    seller_type: {
      type: DataTypes.STRING(100),
      allowNull: true,
    },

    // System Fields
    region: {
      type: DataTypes.STRING(100),
      allowNull: true,
    },
    user_type: {
      type: DataTypes.INTEGER,
      allowNull: true,
      comment: "0=Seller, 1=Creator, 3=Partner",
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
  },
);

//  UPDATED: Static methods dengan user_id filter
Token.findByOpenId = function (openId, userId = null) {
  const where = { open_id: openId };
  if (userId) where.user_id = userId;

  return this.findOne({ where });
};

Token.findByShopId = function (shopId, userId = null) {
  const where = { shop_id: shopId };
  if (userId) where.user_id = userId;

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
