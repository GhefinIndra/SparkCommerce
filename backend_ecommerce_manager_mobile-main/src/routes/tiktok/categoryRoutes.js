const express = require("express");

console.log("DEBUG - About to import categoryController...");
const categoryController = require("../../controllers/tiktok/categoryController");
console.log("DEBUG - categoryController imported:", typeof categoryController);
console.log(
  "DEBUG - getCategories method exists:",
  typeof categoryController.getCategories,
);

const router = express.Router();

// Get main categories
router.get("/:shop_id", async (req, res) => {
  console.log("DEBUG - Route handler started");
  console.log("DEBUG - req.params:", req.params);

  try {
    console.log("DEBUG - About to call getCategories...");
    const result = await categoryController.getCategories(req, res);
    console.log("DEBUG - getCategories completed normally");
  } catch (error) {
    console.log("DEBUG - ERROR CAUGHT:", error.message);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: error.message,
        debug_error: "Caught in route handler",
      });
    }
  }
});

//  ADD: Get category attributes - sesuai frontend call
router.get(
  "/:shop_id/:category_id/attributes",
  categoryController.getCategoryAttributes,
);

router.get("/:shop_id/size-charts", categoryController.getSizeChartTemplates);

// GET /api/categories/:shop_id/:category_id/rules-with-sizechart
// Get category rules with size chart validation and templates
router.get(
  "/:shop_id/:category_id/rules-with-sizechart",
  categoryController.getCategoryRulesWithSizeChart,
);

module.exports = router;
