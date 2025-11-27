// backend_ecommerce_manager_mobile/src/controllers/customerServiceController.js
const Token = require("../../models/Token");
const customerServiceAPI = require("../../services/tiktok/customerServiceAPI");

class CustomerServiceController {
  // Get all conversations for a shop
  async getConversations(req, res) {
    try {
      const { shopId } = req.params;
      const { page_size = 20, page_token = "", locale = "id-ID" } = req.query;

      console.log(` Getting conversations for shop: ${shopId}`);

      const token = await Token.findByShopId(shopId);

      if (!token) {
        return res.status(404).json({
          success: false,
          message: "Shop not found or token expired",
        });
      }

      const response = await customerServiceAPI.getConversations(
        token.access_token,
        token.shop_cipher,
        parseInt(page_size),
        page_token,
        locale,
      );

      if (response.code !== 0) {
        throw new Error(response.message || "Failed to get conversations");
      }

      // Format conversations untuk mobile
      const formattedConversations = (response.data?.conversations || []).map(
        (conv) => ({
          id: conv.id,
          unreadCount: conv.unread_count || 0,
          canSendMessage: conv.can_send_message || false,
          createTime: conv.create_time
            ? new Date(conv.create_time * 1000).toISOString()
            : "",
          participantCount: conv.participant_count || 0,
          buyer: conv.participants?.find((p) => p.role === "BUYER") || {},
          latestMessage: conv.latest_message
            ? {
                id: conv.latest_message.id,
                type: conv.latest_message.type,
                content: conv.latest_message.content,
                createTime: conv.latest_message.create_time
                  ? new Date(
                      conv.latest_message.create_time * 1000,
                    ).toISOString()
                  : "",
                sender: conv.latest_message.sender || {},
              }
            : null,
        }),
      );

      res.status(200).json({
        success: true,
        message: "Conversations retrieved successfully",
        data: {
          conversations: formattedConversations,
          nextPageToken: response.data?.next_page_token || null,
          shop: {
            id: shopId,
            name: token.shop_name || `Toko ${shopId}`,
          },
        },
      });
    } catch (error) {
      console.error(
        ` Error getting conversations for ${req.params.shopId}:`,
        error,
      );
      res.status(500).json({
        success: false,
        message: "Failed to retrieve conversations",
        error: error.message,
      });
    }
  }

  // Get messages from specific conversation
  async getMessages(req, res) {
    try {
      const { shopId, conversationId } = req.params;
      const { page_size = 10, page_token = "", locale = "id-ID" } = req.query;

      console.log(` Getting messages for conversation: ${conversationId}`);

      const token = await Token.findByShopId(shopId);

      if (!token) {
        return res.status(404).json({
          success: false,
          message: "Shop not found or token expired",
        });
      }

      const response = await customerServiceAPI.getConversationMessages(
        token.access_token,
        token.shop_cipher,
        conversationId,
        parseInt(page_size),
        page_token,
        locale,
      );

      if (response.code !== 0) {
        throw new Error(response.message || "Failed to get messages");
      }

      // Format messages untuk mobile
      const formattedMessages = (response.data?.messages || []).map((msg) => ({
        id: msg.id,
        type: msg.type,
        content: msg.content,
        createTime: msg.create_time
          ? new Date(msg.create_time * 1000).toISOString()
          : "",
        isVisible: msg.is_visible || false,
        index: msg.index,
        sender: msg.sender || {},
      }));

      res.status(200).json({
        success: true,
        message: "Messages retrieved successfully",
        data: {
          messages: formattedMessages,
          nextPageToken: response.data?.next_page_token || null,
          unsupportedMsgTips: response.data?.unsupported_msg_tips || null,
        },
      });
    } catch (error) {
      console.error(` Error getting messages:`, error);
      res.status(500).json({
        success: false,
        message: "Failed to retrieve messages",
        error: error.message,
      });
    }
  }

  // Create new conversation
  async createConversation(req, res) {
    try {
      const { shopId } = req.params;
      const { buyer_user_id } = req.body;

      if (!buyer_user_id) {
        return res.status(400).json({
          success: false,
          message: "buyer_user_id is required",
        });
      }

      console.log(` Creating conversation for buyer: ${buyer_user_id}`);

      const token = await Token.findByShopId(shopId);

      if (!token) {
        return res.status(404).json({
          success: false,
          message: "Shop not found or token expired",
        });
      }

      const response = await customerServiceAPI.createConversation(
        token.access_token,
        token.shop_cipher,
        buyer_user_id,
      );

      if (response.code !== 0) {
        throw new Error(response.message || "Failed to create conversation");
      }

      res.status(200).json({
        success: true,
        message: "Conversation created successfully",
        data: {
          conversationId: response.data?.conversation_id,
        },
      });
    } catch (error) {
      console.error(` Error creating conversation:`, error);
      res.status(500).json({
        success: false,
        message: "Failed to create conversation",
        error: error.message,
      });
    }
  }

  // Send message
  async sendMessage(req, res) {
    try {
      const { shopId, conversationId } = req.params;
      const { type, content } = req.body;

      if (!type || !content) {
        return res.status(400).json({
          success: false,
          message: "type and content are required",
        });
      }

      console.log(
        ` Sending ${type} message to conversation: ${conversationId}`,
      );

      const token = await Token.findByShopId(shopId);

      if (!token) {
        return res.status(404).json({
          success: false,
          message: "Shop not found or token expired",
        });
      }

      const response = await customerServiceAPI.sendMessage(
        token.access_token,
        token.shop_cipher,
        conversationId,
        type,
        content,
      );

      if (response.code !== 0) {
        throw new Error(response.message || "Failed to send message");
      }

      res.status(200).json({
        success: true,
        message: "Message sent successfully",
        data: {
          messageId: response.data?.message_id,
        },
      });
    } catch (error) {
      console.error(` Error sending message:`, error);
      res.status(500).json({
        success: false,
        message: "Failed to send message",
        error: error.message,
      });
    }
  }

  // Mark messages as read
  async readMessages(req, res) {
    try {
      const { shopId, conversationId } = req.params;

      console.log(
        `️ Marking messages as read for conversation: ${conversationId}`,
      );

      const token = await Token.findByShopId(shopId);

      if (!token) {
        return res.status(404).json({
          success: false,
          message: "Shop not found or token expired",
        });
      }

      const response = await customerServiceAPI.readMessages(
        token.access_token,
        token.shop_cipher,
        conversationId,
      );

      if (response.code !== 0) {
        throw new Error(response.message || "Failed to mark messages as read");
      }

      res.status(200).json({
        success: true,
        message: "Messages marked as read successfully",
      });
    } catch (error) {
      console.error(` Error marking messages as read:`, error);
      res.status(500).json({
        success: false,
        message: "Failed to mark messages as read",
        error: error.message,
      });
    }
  }

  // Upload image
  async uploadImage(req, res) {
    try {
      const { shopId } = req.params;

      if (!req.file) {
        return res.status(400).json({
          success: false,
          message: "Image file is required",
        });
      }

      console.log(`️ Uploading image for shop: ${shopId}`);

      const token = await Token.findByShopId(shopId);

      if (!token) {
        return res.status(404).json({
          success: false,
          message: "Shop not found or token expired",
        });
      }

      const response = await customerServiceAPI.uploadImage(
        token.access_token,
        token.shop_cipher,
        req.file,
      );

      if (response.code !== 0) {
        throw new Error(response.message || "Failed to upload image");
      }

      res.status(200).json({
        success: true,
        message: "Image uploaded successfully",
        data: {
          url: response.data?.url,
          width: response.data?.width,
          height: response.data?.height,
        },
      });
    } catch (error) {
      console.error(` Error uploading image:`, error);
      res.status(500).json({
        success: false,
        message: "Failed to upload image",
        error: error.message,
      });
    }
  }
}

module.exports = new CustomerServiceController();
