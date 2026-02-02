const { Sequelize } = require("sequelize");
const config = require("./env");

// Buat instance Sequelize
const sequelize = new Sequelize(
  config.database.name,
  config.database.username,
  config.database.password,
  {
    host: config.database.host,
    port: config.database.port,
    dialect: config.database.dialect || "postgres",
    logging: false,
    dialectOptions: config.database.ssl
      ? {
          ssl: {
            require: true,
            rejectUnauthorized: false,
          },
        }
      : undefined,
    pool: {
      max: 5,
      min: 0,
      acquire: 30000,
      idle: 10000,
    },
  },
);

module.exports = sequelize;
