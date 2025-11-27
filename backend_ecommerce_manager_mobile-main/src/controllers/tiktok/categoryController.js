const Token = require("../../models/Token");
const categoryAPI = require("../../services/tiktok/categoryAPI");
const sizeChartAPI = require("../../services/tiktok/sizeChartAPI");

const categoryController = {
  /**
   * Get Categories Tree
   * GET /api/categories/:shop_id
   * Query params: parent_id, keyword, include_prohibited_categories
   */
  getCategories: async (req, res) => {
    try {
      const { shop_id } = req.params;
      const { parent_id, keyword, include_prohibited_categories } = req.query;

      // Get shop token data
      const tokenData = await Token.findByShopId(shop_id);
      if (!tokenData) {
        return res.status(404).json({
          success: false,
          message: "Shop not found",
        });
      }

      const { access_token, shop_cipher } = tokenData;

      // Call TikTok Categories API
      const apiResponse = await categoryAPI.getCategories({
        access_token,
        shop_cipher,
        keyword,
        include_prohibited_categories: include_prohibited_categories === "true",
      });

      if (apiResponse.code === 0) {
        const allCategories = apiResponse.data.categories || [];

        // Filter by parent_id if provided
        let filteredCategories;
        if (parent_id) {
          filteredCategories = allCategories.filter(
            (cat) => cat.parent_id === parent_id,
          );
        } else {
          filteredCategories = allCategories.filter(
            (cat) => cat.parent_id === "0",
          );
        }

        res.json({
          success: true,
          data: filteredCategories,
          total_categories: allCategories.length,
          filtered_count: filteredCategories.length,
          filter_type: parent_id ? "children" : "root",
        });
      } else {
        console.error("TikTok Categories API Error:", {
          code: apiResponse.code,
          message: apiResponse.message,
        });

        res.status(400).json({
          success: false,
          message: apiResponse.message || "Failed to get categories",
          error_code: apiResponse.code,
        });
      }
    } catch (error) {
      console.error("Error getting categories:", {
        message: error.message,
        response: error.response?.data,
        status: error.response?.status,
      });

      res.status(500).json({
        success: false,
        message: "Failed to get categories",
        error: error.response?.data || error.message,
      });
    }
  },

  /**
   * Get Category Rules - additional requirements (certifications, size charts, etc.)
   * GET /api/categories/:shop_id/:category_id/rules
   */
  getCategoryRules: async (req, res) => {
    try {
      const { shop_id, category_id } = req.params;

      // Get shop token data
      const tokenData = await Token.findByShopId(shop_id);
      if (!tokenData) {
        return res.status(404).json({
          success: false,
          message: "Shop not found",
        });
      }

      const { access_token, shop_cipher } = tokenData;

      // Call TikTok Category Rules API
      const apiResponse = await categoryAPI.getCategoryRules({
        category_id,
        access_token,
        shop_cipher,
      });

      if (apiResponse.code === 0) {
        res.json({
          success: true,
          data: apiResponse.data,
          category_id: category_id,
        });
      } else {
        console.error("TikTok Category Rules API Error:", {
          code: apiResponse.code,
          message: apiResponse.message,
        });

        // Handle specific error codes dengan pesan yang user-friendly
        let userMessage = apiResponse.message;
        switch (apiResponse.code) {
          case 12052023:
            userMessage = "Kategori tidak ditemukan";
            break;
          case 12052024:
            userMessage =
              "Kategori ini bukan kategori akhir. Pilih sub-kategori yang lebih spesifik.";
            break;
          case 12052230:
            userMessage =
              "Kategori ini bukan leaf category. Pilih kategori yang lebih spesifik.";
            break;
          case 12052220:
            userMessage =
              "Kategori ini dilarang atau tidak didukung di TikTok Shop.";
            break;
          case 12052223:
          case 12052226:
            userMessage =
              "Kategori ini terbatas. Silakan ajukan melalui Qualification Center di Seller Center.";
            break;
        }

        res.status(400).json({
          success: false,
          message: userMessage,
          error_code: apiResponse.code,
          category_id: category_id,
        });
      }
    } catch (error) {
      console.error("Error getting category rules:", {
        message: error.message,
        category_id: req.params.category_id,
        response: error.response?.data,
      });

      res.status(500).json({
        success: false,
        message: "Gagal mengambil aturan kategori",
        error: error.response?.data || error.message,
        category_id: req.params.category_id,
      });
    }
  },

  /**
   * Get Category Attributes - mandatory and optional product attributes
   * GET /api/categories/:shop_id/:category_id/attributes
   */
  getCategoryAttributes: async (req, res) => {
    try {
      const { shop_id, category_id } = req.params;

      // Get shop token data
      const tokenData = await Token.findByShopId(shop_id);
      if (!tokenData) {
        return res.status(404).json({
          success: false,
          message: "Shop not found",
        });
      }

      const { access_token, shop_cipher } = tokenData;

      // Call TikTok Category Attributes API
      const apiResponse = await categoryAPI.getCategoryAttributes({
        category_id,
        access_token,
        shop_cipher,
      });

      if (apiResponse.code === 0) {
        // Normalize TikTok attributes - fix API typo "is_requried" -> "is_required"
        const normalizedAttributes = (apiResponse.data.attributes || []).map(attr => ({
          ...attr,
          is_required: attr.is_requried || attr.is_required || false,
        }));

        // Count required attributes for logging
        const requiredCount = normalizedAttributes.filter(attr => attr.is_required).length;

        console.log(' Category Attributes API Response:', {
          code: apiResponse.code,
          message: apiResponse.message,
          attributes_count: normalizedAttributes.length,
          required_attributes: requiredCount,
        });

        // Return TikTok response format with normalized attributes
        res.json({
          success: true,
          code: apiResponse.code,
          data: normalizedAttributes,
          message: apiResponse.message,
          request_id: apiResponse.request_id,
        });
      } else {
        console.error("TikTok Category Attributes API Error:", {
          code: apiResponse.code,
          message: apiResponse.message,
        });

        // Handle specific error codes
        let userMessage = apiResponse.message;
        switch (apiResponse.code) {
          case 12052023:
            userMessage = "Kategori tidak ditemukan";
            break;
          case 12052024:
            userMessage =
              "Kategori ini bukan kategori akhir. Pilih sub-kategori yang lebih spesifik.";
            break;
          case 12052230:
            userMessage =
              "Kategori ini bukan leaf category. Pilih kategori yang lebih spesifik.";
            break;
        }

        res.status(400).json({
          success: false,
          message: userMessage,
          code: apiResponse.code,
          category_id: category_id,
        });
      }
    } catch (error) {
      console.error("Error getting category attributes:", {
        message: error.message,
        category_id: req.params.category_id,
        response: error.response?.data,
      });

      res.status(500).json({
        success: false,
        message: "Gagal mengambil atribut kategori",
        error: error.response?.data || error.message,
        category_id: req.params.category_id,
      });
    }
  },

  /**
   * Get Complete Category Info - rules + attributes in one call
   * GET /api/categories/:shop_id/:category_id/complete
   */
  getCategoryComplete: async (req, res) => {
    try {
      const { shop_id, category_id } = req.params;

      // Get shop token data
      const tokenData = await Token.findByShopId(shop_id);
      if (!tokenData) {
        return res.status(404).json({
          success: false,
          message: "Shop not found",
        });
      }

      const { access_token, shop_cipher } = tokenData;

      // Call TikTok Complete Category API
      const apiResponse = await categoryAPI.getCategoryComplete({
        category_id,
        access_token,
        shop_cipher,
      });

      if (apiResponse.code === 0) {
        const { rules, attributes } = apiResponse.data;
        const categoryAttributes = attributes.attributes || [];

        // Process attributes
        const requiredAttributes = categoryAttributes.filter(
          (attr) => attr.is_requried === true,
        );
        const optionalAttributes = categoryAttributes.filter(
          (attr) => attr.is_requried === false,
        );

        res.json({
          success: true,
          data: {
            category_id: category_id,
            rules: rules,
            attributes: {
              all: categoryAttributes,
              required: requiredAttributes,
              optional: optionalAttributes,
            },
            summary: {
              certifications_required: rules.product_certifications?.length > 0,
              size_chart_required: rules.size_chart?.is_required || false,
              package_dimension_required:
                rules.package_dimension?.is_required || false,
              total_attributes: categoryAttributes.length,
              required_attributes_count: requiredAttributes.length,
              optional_attributes_count: optionalAttributes.length,
            },
          },
        });
      } else {
        console.error("TikTok Complete Category API Error:", {
          code: apiResponse.code,
          message: apiResponse.message,
        });

        res.status(400).json({
          success: false,
          message:
            apiResponse.message || "Gagal mengambil informasi kategori lengkap",
          error_code: apiResponse.code,
          category_id: category_id,
        });
      }
    } catch (error) {
      console.error("Error getting complete category info:", {
        message: error.message,
        category_id: req.params.category_id,
        response: error.response?.data,
      });

      res.status(500).json({
        success: false,
        message: "Gagal mengambil informasi kategori lengkap",
        error: error.response?.data || error.message,
        category_id: req.params.category_id,
      });
    }
  },

  getSizeChartTemplates: async (req, res) => {
    try {
      const { shop_id } = req.params;
      const { keyword, limit } = req.query;

      // Get shop token data
      const tokenData = await Token.findByShopId(shop_id);
      if (!tokenData) {
        return res.status(404).json({
          success: false,
          message: "Shop not found",
        });
      }

      const { access_token, shop_cipher } = tokenData;

      // Call Size Chart API
      const apiResponse = await sizeChartAPI.getSizeChartTemplates({
        access_token,
        shop_cipher,
        keyword: keyword || undefined,
        limit: limit ? parseInt(limit) : undefined,
      });

      if (apiResponse.code === 0) {
        const templates = apiResponse.data.templates || [];

        res.json({
          success: true,
          data: templates,
          total_count: apiResponse.data.total_count,
          next_page_token: apiResponse.data.next_page_token,
          search_keyword: keyword || null,
        });
      } else {
        console.error("TikTok Size Chart API Error:", {
          code: apiResponse.code,
          message: apiResponse.message,
        });

        res.status(400).json({
          success: false,
          message: apiResponse.message || "Failed to get size chart templates",
          error_code: apiResponse.code,
        });
      }
    } catch (error) {
      console.error("Error getting size chart templates:", {
        message: error.message,
        shop_id: req.params.shop_id,
        response: error.response?.data,
      });

      res.status(500).json({
        success: false,
        message: "Gagal mengambil template size chart",
        error: error.response?.data || error.message,
      });
    }
  },

  /**
   * Get Category Rules with Size Chart Validation
   * GET /api/categories/:shop_id/:category_id/rules-with-sizechart
   */
  async getCategoryRulesWithSizeChart(req, res) {
    try {
      const { shop_id, category_id } = req.params;

      // Get shop token data
      const tokenData = await Token.findByShopId(shop_id);
      if (!tokenData) {
        return res.status(404).json({
          success: false,
          message: "Shop not found",
        });
      }

      const { access_token, shop_cipher } = tokenData;

      // Get category rules
      const rulesResponse = await categoryAPI.getCategoryRules({
        category_id,
        access_token,
        shop_cipher,
      });

      if (rulesResponse.code === 0) {
        const rules = rulesResponse.data;

        // Validate size chart requirement
        const sizeChartValidation =
          sizeChartAPI.validateSizeChartRequirement(rules);

        // Get size chart templates if size chart is supported
        let sizeChartTemplates = [];
        if (sizeChartValidation.is_supported) {
          try {
            const templatesResponse = await sizeChartAPI.getSizeChartTemplates({
              access_token,
              shop_cipher,
              limit: 20,
            });

            if (templatesResponse.code === 0) {
              sizeChartTemplates = templatesResponse.data.templates || [];
            }
          } catch (templateError) {
            console.warn(
              "Could not fetch size chart templates:",
              templateError.message,
            );
          }
        }

        res.json({
          success: true,
          data: {
            category_id: category_id,
            rules: rules,
            size_chart: {
              ...sizeChartValidation,
              templates: sizeChartTemplates,
            },
          },
        });
      } else {
        console.error("TikTok Category Rules API Error:", {
          code: rulesResponse.code,
          message: rulesResponse.message,
        });

        // Handle specific error codes
        let userMessage = rulesResponse.message;
        switch (rulesResponse.code) {
          case 12052023:
            userMessage = "Kategori tidak ditemukan";
            break;
          case 12052024:
            userMessage =
              "Kategori ini bukan kategori akhir. Pilih sub-kategori yang lebih spesifik.";
            break;
          case 12052230:
            userMessage =
              "Kategori ini bukan leaf category. Pilih kategori yang lebih spesifik.";
            break;
          case 12052220:
            userMessage =
              "Kategori ini dilarang atau tidak didukung di TikTok Shop.";
            break;
        }

        res.status(400).json({
          success: false,
          message: userMessage,
          error_code: rulesResponse.code,
          category_id: category_id,
        });
      }
    } catch (error) {
      console.error("Error getting category rules with size chart:", {
        message: error.message,
        category_id: req.params.category_id,
        response: error.response?.data,
      });

      res.status(500).json({
        success: false,
        message: "Gagal mengambil aturan kategori dengan size chart",
        error: error.response?.data || error.message,
        category_id: req.params.category_id,
      });
    }
  },
};

module.exports = categoryController;
