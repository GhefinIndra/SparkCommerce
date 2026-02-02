const Token = require("../../models/Token");
const { generateApiSignature } = require("../../utils/tiktokSignature");
const config = require("../../config/env");
const axios = require("axios");
const productApi = require("../../services/tiktok/productAPI");
const categoryAPI = require("../../services/tiktok/categoryAPI");
const WarehouseApiService = require("../../services/tiktok/warehouseAPI");

const createProductController = {
  // Get brands from TikTok Shop API
  getBrands: async (req, res) => {
    try {
      const { shop_id } = req.params;
      const { category_id } = req.query;

      console.log(
        " Getting brands for shop:",
        shop_id,
        "category:",
        category_id,
      );

      // Get shop token data
      const tokenData = await Token.findByShopId(shop_id, null, "tiktok");
      if (!tokenData) {
        return res.status(404).json({
          success: false,
          message: "Shop not found",
        });
      }

      const { access_token, shop_cipher } = tokenData;

      // Generate API signature
      const timestamp = Math.floor(Date.now() / 1000);
      const appKey = config.tiktok.appKey;
      const appSecret = config.tiktok.appSecret;

      // Parameters for signature generation
      const params = {
        app_key: appKey,
        shop_cipher: shop_cipher,
        timestamp: timestamp,
        category_version: "v1",
        page_size: 100,
        is_authorized: 0, // Get all brands (authorized and unauthorized)
      };

      // Add category_id if provided
      if (category_id) {
        params.category_id = category_id;
      }

      // Generate signature for GET request
      const signature = generateApiSignature(
        "/product/202309/brands",
        params,
        "",
        appSecret,
      );

      // Call TikTok Shop API
      const apiUrl = `${config.tiktok.apiUrl}/product/202309/brands`;

      console.log(" Brands API Call Details:", {
        url: apiUrl,
        params: { ...params, sign: "***" },
        access_token: access_token ? "present" : "missing",
      });

      const response = await axios.get(apiUrl, {
        headers: {
          "Content-Type": "application/json",
          "x-tts-access-token": access_token,
        },
        params: {
          ...params,
          sign: signature,
        },
        timeout: 15000,
      });

      console.log(" TikTok Shop Brands API Response:", {
        code: response.data.code,
        message: response.data.message,
        brandsCount: response.data.data?.brands?.length || 0,
      });

      if (response.data.code === 0) {
        const brands = response.data.data.brands || [];

        console.log(
          " Sample brand data (first 3 brands):",
          brands.slice(0, 3).map((brand) => ({
            id: brand.id,
            name: brand.name,
            authorized_status: brand.authorized_status,
            brand_status: brand.brand_status,
            is_t1_brand: brand.is_t1_brand,
            // Tampilkan semua properties untuk memastikan
            allProperties: Object.keys(brand),
          })),
        );
        // Custom options dengan ID yang valid untuk API
        const customOptions = [
          {
            id: "", // ID kosong untuk "Tidak Ada Merek" - valid untuk TikTok API
            name: "Tidak Ada Merek",
            is_custom: true,
            authorized_status: "AUTHORIZED",
            brand_status: "AVAILABLE",
          },
          {
            id: "add_new_brand",
            name: "Tambahkan merek baru",
            is_custom: true,
            authorized_status: "AUTHORIZED",
            brand_status: "AVAILABLE",
          },
        ];

        // Filter brands yang valid sesuai dokumentasi TikTok
        const validBrands = brands.filter((brand) => {
          return (
            // Authorized brands with available status
            (brand.authorized_status === "AUTHORIZED" &&
              brand.brand_status === "AVAILABLE") ||
            // Unauthorized non-T1 brands
            (brand.authorized_status === "UNAUTHORIEZD" &&
              brand.is_t1_brand === false)
          );
        });

        console.log(` Brand filtering results:`, {
          total_from_api: brands.length,
          valid_brands: validBrands.length,
          custom_options: customOptions.length,
        });

        // Gabungkan custom options dengan valid brands dari API
        const allBrands = [...customOptions, ...validBrands];

        console.log(
          ` Found ${validBrands.length} valid API brands + ${customOptions.length} custom options`,
        );

        res.json({
          success: true,
          data: allBrands,
          total_count: allBrands.length,
          api_brands_count: validBrands.length,
          custom_options_count: customOptions.length,
          filtered_count: brands.length - validBrands.length,
          next_page_token: response.data.data.next_page_token || null,
        });
      } else {
        console.error(" TikTok Shop Brands API Error:", {
          code: response.data.code,
          message: response.data.message,
        });
        res.status(400).json({
          success: false,
          message: response.data.message || "Failed to get brands",
          error_code: response.data.code,
        });
      }
    } catch (error) {
      console.error(" Error getting brands:", {
        message: error.message,
        response: error.response?.data,
        status: error.response?.status,
      });

      res.status(500).json({
        success: false,
        message: "Failed to get brands",
        error: error.response?.data || error.message,
      });
    }
  },

  // Create custom brand
  createBrand: async (req, res) => {
    try {
      const { shop_id } = req.params;
      const { name } = req.body;

      console.log(' Creating custom brand:', name, 'for shop:', shop_id);

      if (!name || name.trim().length < 2 || name.trim().length > 30) {
        return res.status(400).json({
          success: false,
          message: 'Brand name must be between 2-30 characters',
        });
      }

      // Get shop token data
      const tokenData = await Token.findByShopId(shop_id, null, "tiktok");
      if (!tokenData) {
        return res.status(404).json({
          success: false,
          message: 'Shop not found',
        });
      }

      const { access_token, shop_cipher } = tokenData;

      // Generate API signature
      const timestamp = Math.floor(Date.now() / 1000);
      const appKey = config.tiktok.appKey;
      const appSecret = config.tiktok.appSecret;

      const params = {
        app_key: appKey,
        timestamp: timestamp,
      };

      const body = JSON.stringify({ name: name.trim() });

      // Generate signature for POST request
      const signature = generateApiSignature(
        '/product/202309/brands',
        params,
        body,
        appSecret,
      );

      // Call TikTok Shop API
      const apiUrl = `${config.tiktok.apiUrl}/product/202309/brands`;

      console.log(' Create Brand API Call:', {
        url: apiUrl,
        brand_name: name,
      });

      const response = await axios.post(apiUrl, body, {
        headers: {
          'Content-Type': 'application/json',
          'x-tts-access-token': access_token,
        },
        params: {
          ...params,
          sign: signature,
        },
        timeout: 15000,
      });

      console.log(' TikTok Shop Create Brand Response:', {
        code: response.data.code,
        message: response.data.message,
        brand_id: response.data.data?.id,
      });

      if (response.data.code === 0) {
        res.json({
          success: true,
          message: 'Brand created successfully',
          data: {
            id: response.data.data.id,
            name: name.trim(),
          },
        });
      } else {
        console.error(' TikTok Shop Create Brand Error:', {
          code: response.data.code,
          message: response.data.message,
        });
        res.status(400).json({
          success: false,
          message: response.data.message || 'Failed to create brand',
          error_code: response.data.code,
        });
      }
    } catch (error) {
      console.error(' Error creating brand:', {
        message: error.message,
        response: error.response?.data,
        status: error.response?.status,
      });

      res.status(500).json({
        success: false,
        message: 'Failed to create brand',
        error: error.response?.data || error.message,
      });
    }
  },

  // Updated createProduct method in createProductController.js

  async createProduct(req, res) {
    try {
      const { shop_id } = req.body;

      if (!shop_id) {
        console.error(" shopId is missing from req.body");
        return res.status(400).json({
          success: false,
          message: "Shop ID is required",
          debug: { params: req.params, url: req.url },
        });
      }

      const productData = req.body;
      console.log(" DEBUG - Product data keys:", Object.keys(productData));

      // Get shop token
      const token = await Token.findByShopId(shop_id, null, "tiktok");
      if (!token) {
        console.error(" No token found for shop_id:", shop_id);
        return res.status(404).json({
          success: false,
          message: "Shop not found or token expired",
        });
      }

      console.log(" Token found for shop:", token.shop_name);

      const { access_token, shop_cipher } = token;

      //  Get warehouse ID
      console.log(" Getting warehouse information...");
      let warehouseId;
      try {
        const warehouseService = new WarehouseApiService();
        warehouseId = await warehouseService.getDefaultWarehouseId(
          access_token,
          shop_cipher,
        );
        console.log(" Got warehouse ID:", warehouseId);
      } catch (warehouseError) {
        console.error(" Failed to get warehouse:", warehouseError.message);
        return res.status(400).json({
          success: false,
          message: "Failed to get warehouse information",
          error: warehouseError.message,
          debug: { step: "warehouse_fetch", shop_id: shop_id },
        });
      }

      //  Get category rules for validation
      let categoryRules = null;
      if (productData.category_id) {
        try {
          console.log(" Getting category rules for validation...");
          const rulesResponse = await categoryAPI.getCategoryRules({
            category_id: productData.category_id,
            access_token,
            shop_cipher,
          });

          if (rulesResponse.code === 0) {
            categoryRules = rulesResponse.data;
            console.log(" Got category rules:", {
              size_chart_required: categoryRules.size_chart?.is_required,
              certifications_required:
                categoryRules.product_certifications?.length > 0,
              package_dimension_required:
                categoryRules.package_dimension?.is_required,
            });
          } else {
            console.warn(
              "️ Could not fetch category rules:",
              rulesResponse.message,
            );
          }
        } catch (rulesError) {
          console.warn("️ Error fetching category rules:", rulesError.message);
          // Continue without rules - let TikTok API handle validation
        }
      }

      //  VALIDATE SIZE CHART if required
      // NOTE: For Indonesia region, size chart validation is disabled
      // Even though TikTok API may return is_required=true, in practice it's optional
      // Let TikTok API handle validation itself
      if (false && categoryRules?.size_chart?.is_required === true) {
        const hasSizeChart =
          productData.size_chart &&
          ((productData.size_chart.template &&
            productData.size_chart.template.id) ||
            (productData.size_chart.image && productData.size_chart.image.uri));

        if (!hasSizeChart) {
          console.error(" Size chart is required but not provided");
          return res.status(400).json({
            success: false,
            message: "Size chart wajib untuk kategori ini",
            error_code: "SIZE_CHART_REQUIRED",
            debug: {
              category_id: productData.category_id,
              size_chart_required: true,
              size_chart_provided: false,
            },
          });
        }
      }

      //  VALIDATE CERTIFICATIONS if required
      if (categoryRules?.product_certifications?.length > 0) {
        const requiredCerts = categoryRules.product_certifications.filter(
          (cert) => cert.is_required,
        );

        if (requiredCerts.length > 0) {
          const providedCerts = productData.certifications || [];

          for (const requiredCert of requiredCerts) {
            const providedCert = providedCerts.find(
              (cert) => cert.id === requiredCert.id,
            );

            if (
              !providedCert ||
              (!providedCert.images?.length && !providedCert.files?.length)
            ) {
              console.error(
                " Required certification missing:",
                requiredCert.name,
              );
              return res.status(400).json({
                success: false,
                message: `Sertifikat "${requiredCert.name}" wajib untuk kategori ini`,
                error_code: "CERTIFICATION_REQUIRED",
                debug: {
                  category_id: productData.category_id,
                  missing_certification: requiredCert.name,
                },
              });
            }
          }
        }
      }

      // Get category attributes for processing
      let categoryAttributes = [];
      if (productData.category_id) {
        try {
          console.log(" Getting category attributes for processing...");
          const attributesResponse = await categoryAPI.getCategoryAttributes({
            category_id: productData.category_id,
            access_token,
            shop_cipher,
          });

          if (attributesResponse.code === 0) {
            categoryAttributes = attributesResponse.data.attributes || [];
            console.log(" Got category attributes:", {
              total: categoryAttributes.length,
              required: categoryAttributes.filter(
                (attr) => attr.is_requried === true,
              ).length,
            });
          }
        } catch (attrError) {
          console.warn(
            "️ Error fetching category attributes:",
            attrError.message,
          );
        }
      }

      // Process dynamic attributes from frontend
      let processedAttributes = [];
      if (
        productData.product_attributes &&
        Array.isArray(productData.product_attributes)
      ) {
        console.log(" DEBUG - Raw product_attributes from frontend:", JSON.stringify(productData.product_attributes, null, 2));

        // Frontend already sends correct TikTok API format with attribute_values array
        processedAttributes = productData.product_attributes.map((attr) => {
          const categoryAttr = categoryAttributes.find(
            (ca) => ca.id === attr.attribute_id,
          );

          console.log(" Processing attribute:", {
            id: attr.attribute_id,
            name: categoryAttr?.name || "Unknown",
            has_attribute_values: !!attr.attribute_values,
            has_custom_value: !!attr.custom_value,
            is_required: categoryAttr?.is_requried || false,
          });

          // Return attribute as-is (already in correct format from frontend)
          return attr;
        });

        console.log(" Processed attributes:", processedAttributes.length);
        console.log(" DEBUG - Final attributes to send to TikTok:", JSON.stringify(processedAttributes, null, 2));
      }

      //  Build product payload WITH category rules support
      // DEBUG: Log brand_id value
      console.log(' DEBUG - Brand ID from frontend:', {
        brand_id: productData.brand_id,
        type: typeof productData.brand_id,
        isEmpty: productData.brand_id === '',
        isNoBrand: productData.brand_id === 'no_brand',
        isAddNew: productData.brand_id === 'add_new_brand',
      });

      //  Convert weight from grams to kilograms
      const weightInGrams = parseFloat(productData.weight || 500);
      const weightInKilograms = (weightInGrams / 1000).toFixed(3);
      console.log(' Weight conversion:', {
        input_grams: weightInGrams,
        output_kilograms: weightInKilograms,
      });

      const productPayload = {
        title: productData.title,
        description: productData.description,
        category_id: productData.category_id,
        // TikTok API does not accept:
        // - empty string
        // - 'no_brand'
        // - 'add_new_brand'
        // - 'custom_*' (temporary frontend IDs before brand creation)
        ...(productData.brand_id &&
            productData.brand_id !== '' &&
            productData.brand_id !== 'no_brand' &&
            productData.brand_id !== 'add_new_brand' &&
            !productData.brand_id.toString().startsWith('custom_') // FIX: Filter custom_ IDs
              ? { brand_id: productData.brand_id }
              : {}),
        main_images: (productData.main_images || []).map((imageUri) => {
          if (typeof imageUri === "string") {
            return { uri: imageUri };
          }
          return imageUri;
        }),
        package_weight: {
          // Frontend sends weight in GRAMS (e.g., 59)
          // TikTok API requires KILOGRAM unit (e.g., 0.059)
          value: weightInKilograms,
          unit: "KILOGRAM",
        },
        package_dimensions: {
          length: String(productData.package_dimensions?.length || "10"),
          width: String(productData.package_dimensions?.width || "10"),
          height: String(productData.package_dimensions?.height || "10"),
          unit: "CENTIMETER",
        },
        is_cod_allowed: productData.is_cod_allowed || false,
        shipping_insurance_requirement:
          productData.shipping_insurance || "OPTIONAL",
        skus: [
          {
            seller_sku: productData.seller_sku || `SKU-${Date.now()}`,
            price: {
              currency: "IDR",
              amount: String(productData.price || "1000"),
            },
            inventory: [
              {
                warehouse_id: warehouseId,
                quantity: parseInt(productData.stock) || 0, // FIX: Use 'stock' not 'stock_quantity', fallback to 0
              },
            ],
            sales_attributes: [],
          },
        ],
        product_attributes: processedAttributes,
      };

      //  ADD SIZE CHART if provided
      if (productData.size_chart) {
        console.log(" Adding size chart to payload:", productData.size_chart);
        productPayload.size_chart = {};

        // Add template if provided
        if (
          productData.size_chart.template &&
          productData.size_chart.template.id
        ) {
          productPayload.size_chart.template = {
            id: productData.size_chart.template.id,
          };
          console.log(
            " Size chart template added:",
            productData.size_chart.template.id,
          );
        }

        // Add custom image if provided
        if (productData.size_chart.image && productData.size_chart.image.uri) {
          productPayload.size_chart.image = {
            uri: productData.size_chart.image.uri,
          };
          console.log(
            " Size chart image added:",
            productData.size_chart.image.uri,
          );
        }
      }

      //  ADD CERTIFICATIONS if provided
      if (
        productData.certifications &&
        Array.isArray(productData.certifications)
      ) {
        console.log(
          " Adding certifications to payload:",
          productData.certifications.length,
        );
        productPayload.certifications = productData.certifications;
      }

      // Add optional fields
      if (productData.condition) {
        productPayload.condition = productData.condition;
      }

      if (productData.is_pre_order !== undefined) {
        productPayload.is_pre_order = productData.is_pre_order;
      }

      console.log(
        " DEBUG - Final product payload keys:",
        Object.keys(productPayload),
      );
      console.log(" Creating product WITH category rules support");

      // Create product via TikTok API
      const result = await productApi.createProduct(
        access_token,
        productPayload,
        shop_cipher,
      );

      console.log(" DEBUG - API result code:", result.code);

      if (result.code !== 0) {
        console.error(" API returned error:", result);

        if (
          result.message &&
          result.message.includes("Missing product attribute")
        ) {
          return res.status(400).json({
            success: false,
            message: "Missing required product attributes",
            error: result.message,
            error_code: result.code,
            suggestion:
              "Please ensure all required attributes for this category are filled",
          });
        }

        if (result.message && result.message.includes("size chart")) {
          return res.status(400).json({
            success: false,
            message: "Size chart diperlukan untuk kategori ini",
            error: result.message,
            error_code: result.code,
            suggestion:
              "Please add a size chart template or upload a size chart image",
          });
        }

        throw new Error(result.message || "Failed to create product");
      }

      console.log(
        " Product created successfully with category rules support",
      );

      res.status(200).json({
        success: true,
        message: "Product created successfully",
        data: {
          product_id: result.data.product_id,
          warehouse_id: warehouseId,
          attributes_count: processedAttributes.length,
          has_size_chart: !!productData.size_chart,
          has_certifications: !!productData.certifications?.length,
          skus: result.data.skus || [],
          warnings: result.data.warnings || [],
          // ADD sku_mapping for auto-linking to SKU Master
          sku_mapping: {
            product_id: result.data.product_id,
            marketplace: "TIKTOK",
            warehouse_id: warehouseId,
            skus: (result.data.skus || []).map((sku) => ({
              sku_id: sku.id,
              seller_sku: sku.seller_sku,
              warehouse_id: warehouseId,
            })),
          },
        },
      });
    } catch (error) {
      console.error(" Error creating product:", error);
      console.error(" Error stack:", error.stack);

      res.status(500).json({
        success: false,
        message: "Failed to create product",
        error: error.message,
        debug: {
          params: req.params,
          url: req.url,
          body_keys: req.body ? Object.keys(req.body) : "no body",
        },
      });
    }
  },
};

module.exports = createProductController;
