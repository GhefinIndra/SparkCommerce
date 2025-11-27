// controllers/userAuthController.js
const User = require("../../models/User");
const UserShop = require("../../models/UserShop");

// Register new user
exports.register = async (req, res) => {
  try {
    console.log(" User registration attempt...");
    const { name, email, password, group_id } = req.body;

    // Validation
    if (!name || !email || !password) {
      return res.status(400).json({
        success: false,
        message: "Name, email, and password are required",
      });
    }

    // Check if user already exists
    const existingUser = await User.findByEmail(email);
    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: "Email already registered",
      });
    }

    // Password validation
    if (password.length < 6) {
      return res.status(400).json({
        success: false,
        message: "Password must be at least 6 characters",
      });
    }

    // Validate group_id if provided
    if (group_id && group_id.trim().length > 50) {
      return res.status(400).json({
        success: false,
        message: "Group ID cannot exceed 50 characters",
      });
    }

    // Create user
    const user = await User.create({
      name: name.trim(),
      email: email.toLowerCase().trim(),
      password: password,
      status: "active",
      group_id: group_id ? group_id.trim() : null,
    });

    // Generate auth token
    const token = user.generateAuthToken();
    await user.save();

    console.log(" User registered successfully:", email);

    res.status(201).json({
      success: true,
      message: "Registration successful",
      data: {
        user_id: user.id,
        name: user.name,
        email: user.email,
        group_id: user.group_id,
        auth_token: token,
      },
    });
  } catch (error) {
    console.error(" Registration error:", error.message);
    res.status(500).json({
      success: false,
      message: "Registration failed",
    });
  }
};

// Login user
exports.login = async (req, res) => {
  try {
    console.log(" User login attempt...");
    const { email, password } = req.body;

    // Validation
    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: "Email and password are required",
      });
    }

    // Find user
    const user = await User.findByEmail(email.toLowerCase().trim());
    if (!user) {
      return res.status(401).json({
        success: false,
        message: "Invalid email or password",
      });
    }

    // Check password
    const isPasswordValid = await user.comparePassword(password);
    if (!isPasswordValid) {
      return res.status(401).json({
        success: false,
        message: "Invalid email or password",
      });
    }

    // Check if user is active
    if (user.status !== "active") {
      return res.status(401).json({
        success: false,
        message: "Account is inactive",
      });
    }

    // Generate new auth token
    const token = user.generateAuthToken();
    await user.save();

    console.log(" User logged in successfully:", email);

    res.json({
      success: true,
      message: "Login successful",
      data: {
        user_id: user.id,
        name: user.name,
        email: user.email,
        group_id: user.group_id,
        auth_token: token,
      },
    });
  } catch (error) {
    console.error(" Login error:", error.message);
    res.status(500).json({
      success: false,
      message: "Login failed",
    });
  }
};

// Get user profile
exports.profile = async (req, res) => {
  try {
    const { auth_token } = req.headers;

    if (!auth_token) {
      return res.status(401).json({
        success: false,
        message: "Auth token required",
      });
    }

    const user = await User.findByAuthToken(auth_token);
    if (!user) {
      return res.status(401).json({
        success: false,
        message: "Invalid or expired token",
      });
    }

    res.json({
      success: true,
      data: {
        user_id: user.id,
        name: user.name,
        email: user.email,
        phone: user.phone,
        group_id: user.group_id,
      },
    });
  } catch (error) {
    console.error(" Profile error:", error.message);
    res.status(500).json({
      success: false,
      message: "Failed to get profile",
    });
  }
};

// Logout user
exports.logout = async (req, res) => {
  try {
    const { auth_token } = req.headers;

    if (!auth_token) {
      return res.status(401).json({
        success: false,
        message: "Auth token required",
      });
    }

    const user = await User.findByAuthToken(auth_token);
    if (!user) {
      return res.status(401).json({
        success: false,
        message: "Invalid token",
      });
    }

    // Clear auth token
    user.auth_token = null;
    user.token_expires_at = null;
    await user.save();

    console.log(" User logged out:", user.email);

    res.json({
      success: true,
      message: "Logout successful",
    });
  } catch (error) {
    console.error(" Logout error:", error.message);
    res.status(500).json({
      success: false,
      message: "Logout failed",
    });
  }
};

// Update user profile
// Update user profile
exports.updateProfile = async (req, res) => {
  try {
    console.log(" User profile update attempt...");
    const { auth_token } = req.headers;
    const { name, phone, group_id } = req.body;

    // Check auth token
    if (!auth_token) {
      return res.status(401).json({
        success: false,
        message: "Auth token required",
      });
    }

    // Find user by token
    const user = await User.findByAuthToken(auth_token);
    if (!user) {
      return res.status(401).json({
        success: false,
        message: "Invalid or expired token",
      });
    }

    // Validation
    if (!name || name.trim().length === 0) {
      return res.status(422).json({
        success: false,
        message: "Name is required",
        errors: {
          name: ["Name field is required"],
        },
      });
    }

    // Validate phone if provided
    if (phone && phone.trim().length > 0) {
      // Basic phone validation (adjust as needed)
      const phoneRegex = /^[0-9+\-\s()]+$/;
      if (!phoneRegex.test(phone.trim())) {
        return res.status(422).json({
          success: false,
          message: "Invalid phone number format",
          errors: {
            phone: ["Phone number contains invalid characters"],
          },
        });
      }
    }

    // Validate group_id if provided
    if (group_id && group_id.trim().length > 50) {
      return res.status(422).json({
        success: false,
        message: 'Group ID cannot exceed 50 characters',
        errors: {
          group_id: ['Group ID maksimal 50 karakter']
        }
      });
    }

    // Update using User.update() method
    await User.update(
      {
        name: name.trim(),
        phone: phone !== undefined ? (phone.trim() || null) : user.phone,
        group_id: group_id !== undefined ? (group_id ? group_id.trim() : null) : user.group_id
      },
      { where: { id: user.id } }
    );

    // Reload user untuk ambil data terbaru
    await user.reload();

    console.log(' User profile updated successfully:', user.email);
    console.log(' Final group_id:', user.group_id); // Debug log

    res.json({
      success: true,
      message: "Profile updated successfully",
      data: {
        user_id: user.id,
        name: user.name,
        email: user.email,
        phone: user.phone,
        group_id: user.group_id,
      },
    });
  } catch (error) {
    console.error(" Profile update error:", error.message);
    res.status(500).json({
      success: false,
      message: "Failed to update profile",
    });
  }
};

// Change password
exports.changePassword = async (req, res) => {
  try {
    console.log(" User password change attempt...");
    const { auth_token } = req.headers;
    const { current_password, new_password, new_password_confirmation } =
      req.body;

    // Check auth token
    if (!auth_token) {
      return res.status(401).json({
        success: false,
        message: "Auth token required",
      });
    }

    // Find user by token
    const user = await User.findByAuthToken(auth_token);
    if (!user) {
      return res.status(401).json({
        success: false,
        message: "Invalid or expired token",
      });
    }

    // Validation
    if (!current_password || !new_password) {
      return res.status(422).json({
        success: false,
        message: "Current password and new password are required",
        errors: {
          current_password: !current_password
            ? ["Current password is required"]
            : [],
          new_password: !new_password ? ["New password is required"] : [],
        },
      });
    }

    // Validate new password length
    if (new_password.length < 6) {
      return res.status(422).json({
        success: false,
        message: "New password must be at least 6 characters",
        errors: {
          new_password: ["Password must be at least 6 characters long"],
        },
      });
    }

    // Check if new password confirmation matches (if provided)
    if (
      new_password_confirmation &&
      new_password !== new_password_confirmation
    ) {
      return res.status(422).json({
        success: false,
        message: "Password confirmation does not match",
        errors: {
          new_password_confirmation: ["Password confirmation does not match"],
        },
      });
    }

    // Verify current password
    const isCurrentPasswordValid = await user.comparePassword(current_password);
    if (!isCurrentPasswordValid) {
      return res.status(400).json({
        success: false,
        message: "Current password is incorrect",
      });
    }

    // Check if new password is different from current
    const isSamePassword = await user.comparePassword(new_password);
    if (isSamePassword) {
      return res.status(400).json({
        success: false,
        message: "New password must be different from current password",
      });
    }

    // Update password
    user.password = new_password; // Akan di-hash oleh model

    // Generate new auth token for security
    const newToken = user.generateAuthToken();
    await user.save();

    console.log(" User password changed successfully:", user.email);

    res.json({
      success: true,
      message: "Password changed successfully",
      data: {
        user_id: user.id,
        name: user.name,
        email: user.email,
        group_id: user.group_id,
        auth_token: newToken,
      },
    });
  } catch (error) {
    console.error(" Password change error:", error.message);
    res.status(500).json({
      success: false,
      message: "Failed to change password",
    });
  }
};
