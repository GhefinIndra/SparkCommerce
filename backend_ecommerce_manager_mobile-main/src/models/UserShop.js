// models/UserShop.js
const { DataTypes } = require("sequelize");
const sequelize = require("../config/sequelize");

const UserShop = sequelize.define(
  "UserShop",
  {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true,
    },
    user_id: {
      type: DataTypes.INTEGER,
      allowNull: false,
    },
    shop_id: {
      type: DataTypes.STRING(255),
      allowNull: false,
    },
    role: {
      type: DataTypes.ENUM("owner", "manager", "staff"),
      defaultValue: "owner",
    },
    status: {
      type: DataTypes.ENUM("active", "inactive"),
      defaultValue: "active",
    },
  },
  {
    tableName: "user_shops",
    timestamps: true,
    createdAt: "created_at",
    updatedAt: "updated_at",

    indexes: [
      {
        unique: true,
        fields: ["user_id", "shop_id"],
      },
    ],
  },
);

// Static methods
UserShop.findUserShops = function (userId) {
  return this.findAll({
    where: {
      user_id: userId,
      status: "active",
    },
    order: [["created_at", "DESC"]],
  });
};

UserShop.findShopUsers = function (shopId) {
  return this.findAll({
    where: {
      shop_id: shopId,
      status: "active",
    },
    order: [["created_at", "DESC"]],
  });
};

UserShop.createRelation = function (userId, shopId, role = "owner") {
  return this.create({
    user_id: userId,
    shop_id: shopId,
    role: role,
    status: "active",
  });
};

module.exports = UserShop;
