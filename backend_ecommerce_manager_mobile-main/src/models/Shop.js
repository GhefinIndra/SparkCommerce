// models/Shop.js
const { DataTypes } = require("sequelize");
const sequelize = require("../config/sequelize");

const Shop = sequelize.define(
  "Shop",
  {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true,
    },
    marketplace_platform: {
      type: DataTypes.ENUM("tiktok", "shopee", "tokopedia", "lazada", "bukalapak"),
      allowNull: false,
    },
    marketplace_shop_id: {
      type: DataTypes.STRING(255),
      allowNull: false,
    },
    shop_name: {
      type: DataTypes.STRING(500),
      allowNull: true,
    },
    shop_code: {
      type: DataTypes.STRING(255),
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
    region: {
      type: DataTypes.STRING(100),
      allowNull: true,
    },
  },
  {
    tableName: "shops",
    timestamps: true,
    createdAt: "created_at",
    updatedAt: "updated_at",
    indexes: [
      {
        unique: true,
        fields: ["marketplace_platform", "marketplace_shop_id"],
      },
      {
        fields: ["marketplace_platform"],
      },
      {
        fields: ["marketplace_shop_id"],
      },
    ],
  },
);

Shop.findByMarketplaceId = function (platform, marketplaceShopId) {
  return this.findOne({
    where: {
      marketplace_platform: platform,
      marketplace_shop_id: marketplaceShopId,
    },
  });
};

Shop.findOrCreateByMarketplace = async function (platform, marketplaceShopId, payload = {}) {
  const [shop, created] = await this.findOrCreate({
    where: {
      marketplace_platform: platform,
      marketplace_shop_id: marketplaceShopId,
    },
    defaults: payload,
  });

  if (!created && payload && Object.keys(payload).length > 0) {
    // Update only provided, non-null fields
    const updates = {};
    Object.entries(payload).forEach(([key, value]) => {
      if (value !== undefined && value !== null && value !== "") {
        updates[key] = value;
      }
    });
    if (Object.keys(updates).length > 0) {
      await shop.update(updates);
    }
  }

  return shop;
};

Shop.resolveId = async function (platform, marketplaceShopId) {
  const shop = await this.findByMarketplaceId(platform, marketplaceShopId);
  return shop ? shop.id : null;
};

module.exports = Shop;
