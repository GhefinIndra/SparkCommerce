const { DataTypes } = require('sequelize');
const sequelize = require('../config/sequelize');

const Group = sequelize.define('Group', {
  GID: {
    type: DataTypes.STRING(50),
    primaryKey: true,
  },
  nama_group: {
    type: DataTypes.STRING(255),
    allowNull: false,
  },
  url: {
    type: DataTypes.STRING(500),
    allowNull: false,
  },
  secret: {
    type: DataTypes.STRING(255),
    allowNull: false,
  },
}, {
  tableName: 'groups',
  timestamps: true,
  createdAt: 'created_at',
  updatedAt: 'updated_at',
});

// Static method untuk cari group by GID
Group.findByGID = function(gid) {
  return this.findOne({ where: { GID: gid } });
};

module.exports = Group;