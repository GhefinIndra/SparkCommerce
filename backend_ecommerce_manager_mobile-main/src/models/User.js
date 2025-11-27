// models/User.js
const { DataTypes, Op } = require("sequelize"); //  FIXED: Import Op
const sequelize = require("../config/sequelize");
const bcrypt = require("bcryptjs");

const User = sequelize.define(
  "User",
  {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true,
    },
    name: {
      type: DataTypes.STRING(255),
      allowNull: false,
    },
    email: {
      type: DataTypes.STRING(255),
      allowNull: false,
      // unique: true, //  REMOVED: Duplicate index definition (already in indexes array below)
    },
    password: {
      type: DataTypes.STRING(255),
      allowNull: false,
    },
    phone: {
      type: DataTypes.STRING(20),
      allowNull: true,
    },
    group_id: {
      type: DataTypes.STRING(50),
      allowNull: true,
    },
    auth_token: {
      type: DataTypes.STRING(500),
      allowNull: true,
      comment: "Token for user session",
    },
    token_expires_at: {
      type: DataTypes.DATE,
      allowNull: true,
    },
    status: {
      type: DataTypes.ENUM("active", "inactive"),
      defaultValue: "active",
    },
  },
  {
    tableName: "users",
    timestamps: true,
    createdAt: "created_at",
    updatedAt: "updated_at",

    indexes: [
      {
        unique: true,
        fields: ["email"],
      },
      {
        fields: ["auth_token"],
      },
    ],
  },
);

// Hash password before saving
User.beforeCreate(async (user) => {
  if (user.password) {
    user.password = await bcrypt.hash(user.password, 12);
  }
});

User.beforeUpdate(async (user) => {
  if (user.changed("password")) {
    user.password = await bcrypt.hash(user.password, 12);
  }
});

// Instance method to check password
User.prototype.comparePassword = async function (candidatePassword) {
  return await bcrypt.compare(candidatePassword, this.password);
};

// Generate auth token
User.prototype.generateAuthToken = function () {
  const token = require("crypto").randomBytes(32).toString("hex");
  const expiresAt = new Date();
  expiresAt.setDate(expiresAt.getDate() + 30); // 30 days

  this.auth_token = token;
  this.token_expires_at = expiresAt;

  return token;
};

// Static methods
User.findByEmail = function (email) {
  return this.findOne({ where: { email: email } });
};

User.findByAuthToken = function (token) {
  return this.findOne({
    where: {
      auth_token: token,
      token_expires_at: {
        [Op.gt]: new Date(), //  FIXED: Use imported Op
      },
      status: "active",
    },
  });
};

User.getActiveUsers = function () {
  return this.findAll({
    where: { status: "active" },
    order: [["created_at", "DESC"]],
  });
};

module.exports = User;
