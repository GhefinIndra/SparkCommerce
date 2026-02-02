// src/controllers/productController.js
const Token = require("../../models/Token");
const UserShop = require("../../models/UserShop");
const productApi = require("../../services/tiktok/productAPI");
const { Op } = require("sequelize");

const getPublicShopId = (token, fallback = null) =>
  token?.marketplace_shop_id || token?.shop_id || fallback;

class ProductController {
  // Get all shops untuk mobile dashboard
  async getShops(req, res) {
    try {
      console.log(" Getting all shops for mobile...");

      const userId = req.user?.id;
      if (!userId) {
        return res.status(401).json({
          success: false,
          message: "Authentication required",
        });
      }

      const userShops = await UserShop.findUserShops(userId);
      const shopIds = userShops.map((shop) => shop.shop_id);

      if (shopIds.length === 0) {
        return res.status(200).json({
          success: true,
          message: "No shops found",
          data: [],
        });
      }

      const tokens = await Token.findAll({
        where: {
          shop_id: { [Op.in]: shopIds },
          status: "active",
          platform: "tiktok",
        },
        order: [["updated_at", "DESC"]],
      });

      console.log(" Found active tokens:", tokens.length);

      if (!tokens || tokens.length === 0) {
        return res.status(200).json({
          success: true,
          message: "No shops found",
          data: [],
        });
      }

      const shops = [];

      for (const token of tokens) {
        try {
          const shopId = token.shop_id;
          console.log(` Processing shop: ${shopId}`);

          shops.push({
            id: getPublicShopId(token, shopId),
            internal_id: shopId,
            name: token.shop_name || `Toko ${shopId}`,
            sellerName: token.seller_name || "Unknown Seller",
            platform: "TikTok Shop",
            region: token.shop_region || token.region || "",
            lastSync: new Date(token.updated_at).toLocaleString("id-ID"),
            status: token.status,
          });
        } catch (error) {
          console.log(`️ Error processing shop ${token.id}:`, error.message);
        }
      }

      console.log(" Successfully processed", shops.length, "shops");

      res.status(200).json({
        success: true,
        message: "Shops retrieved successfully",
        data: shops,
      });
    } catch (error) {
      console.error(" Error in getShops:", error);
      res.status(500).json({
        success: false,
        message: "Failed to retrieve shops",
        error: error.message,
      });
    }
  }

  // Get products untuk shop tertentu
  async getProducts(req, res) {
    try {
      const { shopId } = req.params;
      const { page = 1, limit = 20 } = req.query;

      console.log(` Getting products for shop: ${shopId}`);

      const token = await Token.findByShopId(shopId, null, "tiktok");

      if (!token) {
        return res.status(404).json({
          success: false,
          message: "Shop not found or token expired",
        });
      }

      console.log(" Using shop_cipher:", token.shop_cipher);

      const productsResponse = await productApi.getProducts(
        token.access_token,
        token.shop_cipher,
        parseInt(limit),
        page > 1 ? `page_${page}` : "",
      );

      if (productsResponse.code !== 0) {
        throw new Error(productsResponse.message || "Failed to fetch products");
      }

      // Format products untuk mobile display
      // Format products untuk mobile display
      const formattedProducts = (productsResponse.data?.products || []).map(
        (product) => {
          console.log(" Product raw data:", JSON.stringify(product, null, 2));

          return {
            id: product.id,
            title: product.title,
            description: product.description,
            status: product.status,
            mainImage: product.main_images?.[0]?.urls?.[0] || "",
            price: product.skus?.[0]?.price?.tax_exclusive_price || "0", //  FIX: tax_exclusive_price
            currency: product.skus?.[0]?.price?.currency || "IDR",
            stock: product.skus?.[0]?.inventory?.[0]?.quantity || 0, //  FIX: inventory[0].quantity
            skuCount: product.skus?.length || 0,
            createdAt: product.create_time
              ? new Date(product.create_time * 1000).toLocaleDateString("id-ID")
              : "",
            updatedAt: product.update_time
              ? new Date(product.update_time * 1000).toLocaleDateString("id-ID")
              : "",
          };
        },
      );

      res.status(200).json({
        success: true,
        message: "Products retrieved successfully",
        data: {
          products: formattedProducts,
          totalCount: productsResponse.data?.total_count || 0,
          hasNextPage: !!productsResponse.data?.next_page_token,
          shop: {
            id: getPublicShopId(token, shopId),
            internal_id: token.shop_id,
            name: token.shop_name || `Toko ${shopId}`,
          },
        },
      });
    } catch (error) {
      console.error(
        ` Error getting products for ${req.params.shopId}:`,
        error,
      );
      res.status(500).json({
        success: false,
        message: "Failed to retrieve products",
        error: error.message,
      });
    }
  }

  // Get detail produk
  async getProductDetail(req, res) {
    try {
      const { shopId, productId } = req.params;

      const token = await Token.findByShopId(shopId, null, "tiktok");

      if (!token) {
        return res.status(404).json({
          success: false,
          message: "Shop not found or token expired",
        });
      }

      const productResponse = await productApi.getProduct(
        token.access_token,
        productId,
        token.shop_cipher,
      );

      if (productResponse.code !== 0) {
        throw new Error(productResponse.message || "Failed to fetch product");
      }

      const product = productResponse.data;

      console.log(
        " Raw product data from API:",
        JSON.stringify(product, null, 2),
      );

      // Format product detail untuk mobile - LENGKAP SESUAI TIKTOK API
      const formattedProduct = {
        id: product.id,
        title: product.title,
        description: product.description,
        status: product.status,

        //  Main Images
        main_images:
          product.main_images?.map((img) => ({
            url: img.url_list?.[0] || img.urls?.[0] || "",
            thumb: img.thumb_url_list?.[0] || img.thumb_urls?.[0] || "",
            uri: img.uri || "",
            width: img.width || 0,
            height: img.height || 0,
          })) || [],

        //  Category Chains (IMPORTANT!)
        category_chains: product.category_chains || [],

        //  Brand (IMPORTANT!)
        brand: product.brand || null,

        //  Package Info
        package_dimensions: product.package_dimensions || null,
        package_weight: product.package_weight || null,

        //  SKUs
        skus:
          product.skus?.map((sku) => {
            console.log(" Processing SKU:", JSON.stringify(sku, null, 2));

            return {
              id: sku.id,
              seller_sku: sku.seller_sku,
              price: {
                amount:
                  sku.price?.tax_exclusive_price ||
                  sku.price?.amount ||
                  sku.price?.sale_price ||
                  "0",
                currency: sku.price?.currency || "IDR",
                sale_price:
                  sku.price?.sale_price ||
                  sku.price?.tax_exclusive_price ||
                  sku.price?.amount ||
                  "0",
              },
              stock:
                sku.inventory?.[0]?.quantity ||
                sku.stock_infos?.[0]?.available_stock ||
                sku.stock ||
                0,
              warehouse_id:
                sku.stock_infos?.[0]?.warehouse_id ||
                sku.inventory?.[0]?.warehouse_id ||
                "",
              attributes: sku.sales_attributes || [],
            };
          }) || [],

        //  Boolean Flags
        is_cod_allowed: product.is_cod_allowed || false,
        is_not_for_sale: product.is_not_for_sale || false,
        is_pre_owned: product.is_pre_owned || false,
        is_replicated: product.is_replicated || false,
        has_draft: product.has_draft || false,

        //  Additional Fields
        minimum_order_quantity: product.minimum_order_quantity || null,
        external_product_id: product.external_product_id || null,
        product_types: product.product_types || [],
        shipping_insurance_requirement: product.shipping_insurance_requirement || null,
        product_status: product.product_status || product.status,

        //  Product Attributes
        product_attributes: product.product_attributes || [],

        //  Timestamps
        create_time: product.create_time,
        update_time: product.update_time,
        createdAt: product.create_time
          ? new Date(product.create_time * 1000).toISOString()
          : "",
        updatedAt: product.update_time
          ? new Date(product.update_time * 1000).toISOString()
          : "",
      };

      console.log(
        " Formatted product detail:",
        JSON.stringify(formattedProduct, null, 2),
      );

      res.status(200).json({
        success: true,
        message: "Product detail retrieved successfully",
        data: formattedProduct,
      });
    } catch (error) {
      console.error(` Error getting product detail:`, error);
      res.status(500).json({
        success: false,
        message: "Failed to retrieve product detail",
        error: error.message,
      });
    }
  }

  // Update nama dan deskripsi produk
  async updateProductInfo(req, res) {
    try {
      const { shopId, productId } = req.params;
      const { title, description } = req.body;

      if (!title && !description) {
        return res.status(400).json({
          success: false,
          message: "At least title or description is required",
        });
      }

      const token = await Token.findByShopId(shopId, null, "tiktok");

      if (!token) {
        return res.status(404).json({
          success: false,
          message: "Shop not found or token expired",
        });
      }

      const updateData = {};
      if (title) updateData.title = title;
      if (description) updateData.description = description;

      console.log(" Updating product info:", {
        shopId,
        productId,
        updateData,
      });

      const result = await productApi.editProduct(
        token.access_token,
        productId,
        updateData,
        token.shop_cipher,
      );

      res.status(200).json({
        success: true,
        message: "Product info updated successfully",
        data: result,
      });
    } catch (error) {
      console.error(" Error updating product info:", error);
      res.status(500).json({
        success: false,
        message: "Failed to update product info",
        error: error.message,
      });
    }
  }

  // Update harga produk
  async updateProductPrice(req, res) {
    try {
      const { shopId, productId } = req.params;
      const { skus } = req.body;

      if (!skus || !Array.isArray(skus) || skus.length === 0) {
        return res.status(400).json({
          success: false,
          message: "SKUs data is required",
        });
      }

      const token = await Token.findByShopId(shopId, null, "tiktok");

      if (!token) {
        return res.status(404).json({
          success: false,
          message: "Shop not found or token expired",
        });
      }

      console.log(" Updating product price:", {
        shopId,
        productId,
        skuCount: skus.length,
      });

      const result = await productApi.updatePrice(
        token.access_token,
        productId,
        skus,
        token.shop_cipher,
      );

      res.status(200).json({
        success: true,
        message: "Product price updated successfully",
        data: result,
      });
    } catch (error) {
      console.error(" Error updating product price:", error);
      res.status(500).json({
        success: false,
        message: "Failed to update product price",
        error: error.message,
      });
    }
  }

  // Update stock produk
  async updateProductStock(req, res) {
    try {
      const { shopId, productId } = req.params;
      const { skus } = req.body;

      if (!skus || !Array.isArray(skus) || skus.length === 0) {
        return res.status(400).json({
          success: false,
          message: "SKUs data is required",
        });
      }

      const token = await Token.findByShopId(shopId, null, "tiktok");

      if (!token) {
        return res.status(404).json({
          success: false,
          message: "Shop not found or token expired",
        });
      }

      console.log(" Updating product stock:", {
        shopId,
        productId,
        skuCount: skus.length,
      });

      //  Debug: Log SKU data yang diterima dari mobile
      console.log(" SKU data received from mobile:", JSON.stringify(skus, null, 2));

      const result = await productApi.updateInventory(
        token.access_token,
        productId,
        skus,
        token.shop_cipher,
      );

      res.status(200).json({
        success: true,
        message: "Product stock updated successfully",
        data: result,
      });
    } catch (error) {
      console.error(" Error updating product stock:", error);
      res.status(500).json({
        success: false,
        message: "Failed to update product stock",
        error: error.message,
      });
    }
  }

  // Hapus produk
  async deleteProduct(req, res) {
    try {
      const { shopId, productId } = req.params;

      console.log("️ Delete product request:", { shopId, productId });

      const token = await Token.findByShopId(shopId, null, "tiktok");

      if (!token) {
        return res.status(404).json({
          success: false,
          message: "Shop not found or token expired",
        });
      }

      console.log(" Token found, calling TikTok API...");

      const result = await productApi.deleteProduct(
        token.access_token,
        productId,
        token.shop_cipher,
      );

      if (result.code !== 0) {
        throw new Error(result.message || "Failed to delete product");
      }

      console.log(" Product deleted successfully");

      res.status(200).json({
        success: true,
        message: "Product deleted successfully",
        data: result.data,
      });
    } catch (error) {
      console.error(" Error deleting product:", error);
      res.status(500).json({
        success: false,
        message: "Failed to delete product",
        error: error.message,
      });
    }
  }

  // Upload multiple images
  // src/controllers/productController.js
  async uploadProductImages(req, res) {
    try {
      const { shopId } = req.params;
      const file = req.file; // Single file, bukan files array

      console.log(" Single image upload request:", {
        shopId,
        hasFile: !!file,
        filename: file?.originalname,
        size: file?.size,
        useCase: req.body.use_case,
      });

      if (!file) {
        return res.status(400).json({
          success: false,
          message: "No image provided",
        });
      }

      // Check file size (10MB)
      if (file.size > 10 * 1024 * 1024) {
        return res.status(400).json({
          success: false,
          message: "File exceeds 10MB limit",
        });
      }

      const token = await Token.findByShopId(shopId, null, "tiktok");

      if (!token) {
        return res.status(404).json({
          success: false,
          message: "Shop not found or token expired",
        });
      }

      console.log(" Uploading single image:", file.originalname);

      const result = await productApi.uploadProductImage(
        token.access_token,
        file.buffer,
        file.originalname,
        req.body.use_case || "MAIN_IMAGE",
      );

      if (result.code !== 0) {
        throw new Error(
          result.message || `Failed to upload ${file.originalname}`,
        );
      }

      console.log(" Single image upload success");

      res.status(200).json({
        success: true,
        message: "Image uploaded successfully",
        data: {
          uri: result.data.uri,
          url: result.data.url,
          width: result.data.width,
          height: result.data.height,
          use_case: result.data.use_case,
        },
      });
    } catch (error) {
      console.error(" Error uploading single image:", error);
      res.status(500).json({
        success: false,
        message: "Failed to upload image",
        error: error.message,
      });
    }
  }

  // Update product images
  // Update product images (hanya terima URI yang sudah diupload)
  async updateProductImages(req, res) {
    try {
      const { shopId, productId } = req.params;
      const { images } = req.body;

      if (!images || !Array.isArray(images) || images.length === 0) {
        return res.status(400).json({
          success: false,
          message: "Images data is required (min: 1, max: 9)",
        });
      }

      if (images.length > 9) {
        return res.status(400).json({
          success: false,
          message: "Maximum 9 images allowed",
        });
      }

      // Validate image objects
      for (const img of images) {
        if (!img.uri) {
          return res.status(400).json({
            success: false,
            message: "Each image must have uri property",
          });
        }
      }

      const token = await Token.findByShopId(shopId, null, "tiktok");

      if (!token) {
        return res.status(404).json({
          success: false,
          message: "Shop not found or token expired",
        });
      }

      console.log(" Updating product images:", {
        shopId,
        productId,
        imageCount: images.length,
      });

      const result = await productApi.updateProductImages(
        token.access_token,
        productId,
        images,
        token.shop_cipher,
      );

      if (result.code !== 0) {
        throw new Error(result.message || "Failed to update product images");
      }

      console.log(" Product images updated successfully");

      res.status(200).json({
        success: true,
        message: "Product images updated successfully",
        data: result.data,
      });
    } catch (error) {
      console.error(" Error updating product images:", error);
      res.status(500).json({
        success: false,
        message: "Failed to update product images",
        error: error.message,
      });
    }
  }


  async activateProduct(req, res) {
    try {
      const { shopId, productId } = req.params;

      console.log(" Activate product request:", { shopId, productId });
      const token = await Token.findByShopId(shopId, null, "tiktok");

      if (!token) {
        return res.status(404).json({
          success: false,
          message: "Shop not found or token expired",
        });
      }

      console.log(" Token found, calling TikTok Activate API...");
      console.log(" Token details:", {
        shop_id: token.shop_id,
        shop_cipher: token.shop_cipher,
        shop_cipher_exists: !!token.shop_cipher,
        shop_cipher_type: typeof token.shop_cipher,
      });

      const result = await productApi.activateProduct(
        token.access_token,
        productId,
        token.shop_cipher,
      );

      if (result.code !== 0) {
        // Handle specific errors from TikTok API
        let errorMessage = result.message || "Failed to activate product";
        if (result.data?.errors && result.data.errors.length > 0) {
          errorMessage = result.data.errors[0].message || errorMessage;
        }
        throw new Error(errorMessage);
      }

      console.log(" Product activated successfully");
      res.status(200).json({
        success: true,
        message: "Product activated successfully",
        data: result.data,
      });
    } catch (error) {
      console.error(" Error activating product:", error);
      res.status(500).json({
        success: false,
        message: "Failed to activate product",
        error: error.message,
      });
    }
  }

  async deactivateProduct(req, res) {
    try {
      const { shopId, productId } = req.params;

      console.log(" Deactivate product request:", { shopId, productId });
      const token = await Token.findByShopId(shopId, null, "tiktok");

      if (!token) {
        return res.status(404).json({
          success: false,
          message: "Shop not found or token expired",
        });
      }

      console.log(" Token found, calling TikTok Deactivate API...");
      console.log(" Token details:", {
        shop_id: token.shop_id,
        shop_cipher: token.shop_cipher,
        shop_cipher_exists: !!token.shop_cipher,
        shop_cipher_type: typeof token.shop_cipher,
      });

      const result = await productApi.deactivateProduct(
        token.access_token,
        productId,
        token.shop_cipher,
      );

      if (result.code !== 0) {
        // Handle specific errors from TikTok API
        let errorMessage = result.message || "Failed to deactivate product";
        if (result.data?.errors && result.data.errors.length > 0) {
          errorMessage = result.data.errors[0].message || errorMessage;
        }
        throw new Error(errorMessage);
      }

      console.log(" Product deactivated successfully");
      res.status(200).json({
        success: true,
        message: "Product deactivated successfully",
        data: result.data,
      });
    } catch (error) {
      console.error(" Error deactivating product:", error);
      res.status(500).json({
        success: false,
        message: "Failed to deactivate product",
        error: error.message,
      });
    }
  }

  async recoverProduct(req, res) {
    try {
      const { shopId, productId } = req.params;

      console.log(" Recover product request:", { shopId, productId });
      const token = await Token.findByShopId(shopId, null, "tiktok");

      if (!token) {
        return res.status(404).json({
          success: false,
          message: "Shop not found or token expired",
        });
      }

      console.log(" Token found, calling TikTok Recover API...");

      const result = await productApi.recoverProduct(
        token.access_token,
        productId,
        token.shop_cipher,
      );

      if (result.code !== 0) {
        // Handle specific errors from TikTok API
        let errorMessage = result.message || "Failed to recover product";
        if (result.data?.errors && result.data.errors.length > 0) {
          errorMessage = result.data.errors[0].message || errorMessage;
        }
        throw new Error(errorMessage);
      }

      console.log(" Product recovered successfully");
      res.status(200).json({
        success: true,
        message: "Product recovered successfully",
        data: result.data,
      });
    } catch (error) {
      console.error(" Error recovering product:", error);
      res.status(500).json({
        success: false,
        message: "Failed to recover product",
        error: error.message,
      });
    }
  }

  // ============ SKU SYNC METHODS ============

  /**
   * Sync Stock to Marketplace (TikTok/Shopee)
   * POST /api/shops/:shopId/products/:productId/sync-stock
   */
  async syncStockToMarketplace(req, res) {
    try {
      const { shopId, productId } = req.params;
      const { skus, marketplace } = req.body;

      console.log(" Sync stock request:", {
        shopId,
        productId,
        marketplace,
        skus,
      });

      // Validation
      if (!skus || !Array.isArray(skus) || skus.length === 0) {
        return res.status(400).json({
          success: false,
          message: "SKUs array is required",
        });
      }

      if (!marketplace) {
        return res.status(400).json({
          success: false,
          message: "Marketplace is required",
        });
      }

      // Get token
      const token = await Token.findByShopId(shopId, null, "tiktok");

      if (!token) {
        return res.status(404).json({
          success: false,
          message: "Shop not found or token expired",
        });
      }

      // Handle different marketplaces
      if (marketplace === "TIKTOK") {
        console.log(" Syncing to TikTok...");

        const result = await productApi.updateInventory(
          token.access_token,
          productId,
          { skus },
          token.shop_cipher
        );

        if (result.code !== 0) {
          throw new Error(result.message || "Failed to sync stock to TikTok");
        }

        console.log(" TikTok stock synced successfully");

        return res.json({
          success: true,
          message: `Stock synced to ${marketplace} successfully`,
          data: result.data,
        });
      }

      if (marketplace === "SHOPEE") {
        // TODO: Implement Shopee stock sync
        console.log(" Shopee sync - Coming soon");

        return res.status(501).json({
          success: false,
          message: "Shopee sync coming soon",
        });
      }

      // Invalid marketplace
      return res.status(400).json({
        success: false,
        message: `Invalid marketplace: ${marketplace}`,
      });
    } catch (error) {
      console.error(" Error syncing stock:", error);
      res.status(500).json({
        success: false,
        message: "Failed to sync stock",
        error: error.message,
      });
    }
  }

  /**
   * Get Stock from Marketplace
   * GET /api/shops/:shopId/products/:productId/get-stock?marketplace=TIKTOK
   */
  async getStockFromMarketplace(req, res) {
    try {
      const { shopId, productId } = req.params;
      const { marketplace } = req.query;

      console.log(" Get stock request:", {
        shopId,
        productId,
        marketplace,
      });

      if (!marketplace) {
        return res.status(400).json({
          success: false,
          message: "Marketplace query parameter is required",
        });
      }

      // Get token
      const token = await Token.findByShopId(shopId, null, "tiktok");

      if (!token) {
        return res.status(404).json({
          success: false,
          message: "Shop not found or token expired",
        });
      }

      // Handle different marketplaces
      if (marketplace === "TIKTOK") {
        console.log(" Getting stock from TikTok...");

        const result = await productApi.getProductDetail(
          token.access_token,
          productId,
          token.shop_cipher
        );

        if (result.code !== 0) {
          throw new Error(
            result.message || "Failed to get stock from TikTok"
          );
        }

        // Extract SKU stock information
        const skus = (result.data?.skus || []).map((sku) => ({
          id: sku.id,
          sellerSku: sku.seller_sku,
          stock: sku.stock_infos?.[0]?.available_stock || 0,
          warehouseId: sku.stock_infos?.[0]?.warehouse_id || null,
        }));

        console.log(" TikTok stock retrieved:", skus.length, "SKUs");

        return res.json({
          success: true,
          message: "Stock retrieved successfully",
          data: {
            marketplace: "TIKTOK",
            productId,
            skus,
          },
        });
      }

      if (marketplace === "SHOPEE") {
        // TODO: Implement Shopee get stock
        console.log(" Shopee get stock - Coming soon");

        return res.status(501).json({
          success: false,
          message: "Shopee get stock coming soon",
        });
      }

      // Invalid marketplace
      return res.status(400).json({
        success: false,
        message: `Invalid marketplace: ${marketplace}`,
      });
    } catch (error) {
      console.error(" Error getting stock:", error);
      res.status(500).json({
        success: false,
        message: "Failed to get stock",
        error: error.message,
      });
    }
  }
}

module.exports = new ProductController();
