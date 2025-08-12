const SupportQuery = require('../models/supportQuery');
const Activity = require('../models/activity');
const User = require('../models/user');
const Admin = require('../models/admin');

// Helper: Delete queries older than 7 days
const deleteOldQueries = async () => {
  const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
  const oldQueries = await SupportQuery.find({ createdAt: { $lt: sevenDaysAgo } });
  for (const query of oldQueries) {
    await query.deleteOne();
    io.emit('support_query_deleted', { queryId: query._id });
  }
};

module.exports = (io) => {
  // User creates a new support query
  const createSupportQuery = async (req, res) => {
    try {
      await deleteOldQueries();
      const { topic, description } = req.body;
      const userId = req.user._id; // Assuming user ID is available from auth middleware

      const newQuery = new SupportQuery({
        user: userId,
        topic,
        description,
      });

      await newQuery.save();

      // Populate user details for the emitted event
      const populatedQuery = await newQuery.populate('user', 'username email');

      // Emit Socket.IO event for new query
      io.emit('support_query_created', populatedQuery);
      io.to(`query_${newQuery._id}`).emit('support_query_updated', populatedQuery);

      // Log activity
      await Activity.create({
        user: userId,
        type: 'support_query_created',
        title: `Support query created: ${topic}`,
        description: `User submitted a new support query with topic: ${topic}.`,
        metadata: { queryId: newQuery._id, topic, description },
      });

      console.log('Backend: createSupportQuery - Success', populatedQuery);
      res.status(201).json({ message: 'Support query created successfully', query: populatedQuery });
    } catch (error) {
      console.error('Backend: createSupportQuery - Error', error);
      res.status(500).json({ error: 'Failed to create support query', details: error.message });
    }
  };

  // User views their own support queries
  const getUserSupportQueries = async (req, res) => {
    try {
      await deleteOldQueries();
      const userId = req.user._id;
      const queries = await SupportQuery.find({ user: userId }).sort({ createdAt: -1 });
      console.log('Backend: getUserSupportQueries - Success', queries.length, 'queries found');
      res.status(200).json({ queries });
    } catch (error) {
      console.error('Backend: getUserSupportQueries - Error', error);
      res.status(500).json({ error: 'Failed to fetch user support queries', details: error.message });
    }
  };

  // User updates their own support query (only if no admin reply yet)
  const updateSupportQuery = async (req, res) => {
    try {
      await deleteOldQueries();
      const { queryId } = req.params;
      const { topic, description } = req.body;
      const userId = req.user._id;

      const query = await SupportQuery.findOne({ _id: queryId, user: userId });

      if (!query) {
        console.log('Backend: updateSupportQuery - Query not found or no permission', queryId, userId);
        return res.status(404).json({ error: 'Support query not found or you do not have permission to edit it' });
      }

      if (query.replies && query.replies.length > 0) {
        console.log('Backend: updateSupportQuery - Cannot edit after admin reply', queryId);
        return res.status(403).json({ error: 'Cannot edit query after an admin has replied' });
      }

      query.topic = topic || query.topic;
      query.description = description || query.description;
      await query.save();

      // Populate user details for the emitted event
      const populatedQuery = await query.populate('user', 'username email');

      // Emit Socket.IO event for updated query
      io.emit('support_query_updated', populatedQuery);
      io.to(`query_${query._id}`).emit('support_query_updated', populatedQuery);

      // Log activity
      await Activity.create({
        user: userId,
        type: 'support_query_updated',
        title: `Support query updated: ${query.topic}`,
        description: `User updated their support query with ID: ${queryId}.`,
        metadata: { queryId: query._id, newTopic: topic, newDescription: description },
      });

      console.log('Backend: updateSupportQuery - Success', populatedQuery);
      res.status(200).json({ message: 'Support query updated successfully', query: populatedQuery });
    } catch (error) {
      console.error('Backend: updateSupportQuery - Error', error);
      res.status(500).json({ error: 'Failed to update support query', details: error.message });
    }
  };

  // Admin views all support queries
  const getAllSupportQueries = async (req, res) => {
    try {
      await deleteOldQueries();
      const { searchTerm } = req.query; // Search by topic
      let query = {};

      if (searchTerm) {
        query.topic = { $regex: searchTerm, $options: 'i' }; // Case-insensitive search
      }

      const queries = await SupportQuery.find(query)
        .populate('user', 'username email') // Populate user details
        .populate('replies.admin', 'username email') // Populate admin details for replies
        .sort({ createdAt: -1 });

      console.log('Backend: getAllSupportQueries - Success', queries.length, 'queries found');
      res.status(200).json({ queries });
    } catch (error) {
      console.error('Backend: getAllSupportQueries - Error', error);
      res.status(500).json({ error: 'Failed to fetch all support queries', details: error.message });
    }
  };

  // Admin adds a reply to a support query
  const replyToSupportQuery = async (req, res) => {
    try {
      const { queryId } = req.params;
      const { replyText } = req.body;
      const adminId = req.user._id; // Assuming admin ID is available from auth middleware

      const query = await SupportQuery.findById(queryId);

      if (!query) {
        console.log('Backend: replyToSupportQuery - Query not found', queryId);
        return res.status(404).json({ error: 'Support query not found' });
      }

      query.replies.push({ admin: adminId, replyText });
      query.status = 'in_progress'; // Automatically set status to in_progress
      await query.save();

      // Re-fetch the query and populate it for emission
      const populatedQuery = await SupportQuery.findById(queryId)
        .populate('user', 'username email')
        .populate('replies.admin', 'username email');

      // Emit Socket.IO event for updated query with new reply
      io.emit('support_query_updated', populatedQuery);
      io.to(`query_${query._id}`).emit('support_query_updated', populatedQuery);

      // Log activity for the user whose query was replied to
      await Activity.create({
        user: query.user, // The user who created the query
        type: 'support_query_replied',
        title: `Admin replied to your query: ${query.topic}`,
        description: `An admin has replied to your support query with ID: ${queryId}.`,
        metadata: { queryId: query._id, adminId, replyText },
      });

      console.log('Backend: replyToSupportQuery - Success', populatedQuery);
      res.status(200).json({ message: 'Reply added successfully', query: populatedQuery });
    } catch (error) {
      console.error('Backend: replyToSupportQuery - Error', error);
      res.status(500).json({ error: 'Failed to add reply', details: error.message });
    }
  };

  // Admin edits a specific reply
  const editReply = async (req, res) => {
    try {
      const { queryId, replyId } = req.params;
      const { replyText } = req.body;
      const adminId = req.user._id;

      const query = await SupportQuery.findById(queryId);

      if (!query) {
        return res.status(404).json({ error: 'Support query not found' });
      }

      const reply = query.replies.id(replyId);

      if (!reply) {
        return res.status(404).json({ error: 'Reply not found' });
      }

      // Optional: Check if the admin editing is the one who created the reply
      // if (reply.admin.toString() !== adminId.toString()) {
      //   return res.status(403).json({ error: 'You can only edit your own replies' });
      // }

      reply.replyText = replyText;
      await query.save();

      // Populate the query and the edited reply for emission
      const populatedQuery = await query
        .populate('user', 'username email')
        .populate('replies.admin', 'username email');

      // Emit Socket.IO event for updated query with edited reply
      io.emit('support_query_updated', populatedQuery);
      io.to(`query_${query._id}`).emit('support_query_updated', populatedQuery);

      // Log activity for the user whose query's reply was edited
      await Activity.create({
        user: query.user,
        type: 'support_reply_edited',
        title: `Admin edited a reply to your query: ${query.topic}`,
        description: `An admin edited a reply to your support query with ID: ${queryId}.`,
        metadata: { queryId: query._id, replyId, newReplyText: replyText },
      });

      res.status(200).json({ message: 'Reply updated successfully', query: populatedQuery });
    } catch (error) {
      res.status(500).json({ error: 'Failed to update reply', details: error.message });
    }
  };

  // Admin deletes a specific reply
  const deleteReply = async (req, res) => {
    try {
      const { queryId, replyId } = req.params;
      const adminId = req.user._id;

      const query = await SupportQuery.findById(queryId);

      if (!query) {
        return res.status(404).json({ error: 'Support query not found' });
      }

      query.replies.id(replyId).remove();
      await query.save();

      // Populate the query for emission after reply deletion
      const populatedQuery = await query
        .populate('user', 'username email')
        .populate('replies.admin', 'username email');

      // Emit Socket.IO event for updated query after reply deletion
      io.emit('support_query_updated', populatedQuery);
      io.to(`query_${query._id}`).emit('support_query_updated', populatedQuery);

      // Log activity for the user whose query's reply was deleted
      await Activity.create({
        user: query.user,
        type: 'support_reply_deleted',
        title: `Admin deleted a reply to your query: ${query.topic}`,
        description: `An admin deleted a reply to your support query with ID: ${queryId}.`,
        metadata: { queryId: query._id, replyId },
      });

      res.status(200).json({ message: 'Reply deleted successfully', query: populatedQuery });
    } catch (error) {
      res.status(500).json({ error: 'Failed to delete reply', details: error.message });
    }
  };

  // Admin updates the status of a support query
  const updateQueryStatus = async (req, res) => {
    try {
      const { queryId } = req.params;
      const { status } = req.body;
      const adminId = req.user._id;

      if (!['open', 'in_progress', 'resolved', 'closed'].includes(status)) {
        return res.status(400).json({ error: 'Invalid status provided' });
      }

      const query = await SupportQuery.findById(queryId);

      if (!query) {
        return res.status(404).json({ error: 'Support query not found' });
      }

      query.status = status;
      await query.save();

      // Populate the query for emission after status update
      const populatedQuery = await query
        .populate('user', 'username email')
        .populate('replies.admin', 'username email');

      // Emit Socket.IO event for updated query after status change
      io.emit('support_query_updated', populatedQuery);
      io.to(`query_${query._id}`).emit('support_query_updated', populatedQuery);

      // Log activity for the user whose query's status was updated
      await Activity.create({
        user: query.user,
        type: 'support_query_status_updated',
        title: `Your query status updated to: ${status}`,
        description: `The status of your support query (ID: ${queryId}) has been updated to ${status}.`,
        metadata: { queryId: query._id, newStatus: status },
      });

      res.status(200).json({ message: 'Query status updated successfully', query: populatedQuery });
    } catch (error) {
      res.status(500).json({ error: 'Failed to update query status', details: error.message });
    }
  };

  const deleteSupportQuery = async (req, res) => {
    try {
      const { queryId } = req.params;
      const userId = req.user._id;

      const query = await SupportQuery.findOne({ _id: queryId, user: userId });

      if (!query) {
        console.log('Backend: deleteSupportQuery - Query not found or no permission');
        return res.status(404).json({ error: 'Support query not found or you do not have permission to delete it' });
      }

      await query.deleteOne(); // Changed from query.remove()

      io.emit('support_query_deleted', { queryId });

      await Activity.create({
        user: userId,
        type: 'support_query_deleted',
        title: `Support query deleted: ${query.topic}`,
        description: `User deleted their support query with ID: ${queryId}.`,
        metadata: { queryId: query._id },
      });

      console.log('Backend: deleteSupportQuery - Success', queryId);
      res.status(200).json({ message: 'Support query deleted successfully' });
    } catch (error) {
      console.error('Backend: deleteSupportQuery - Error', error);
      res.status(500).json({ error: 'Failed to delete support query', details: error.message });
    }
  };

  return {
    createSupportQuery,
    getUserSupportQueries,
    updateSupportQuery,
    deleteSupportQuery,
    getAllSupportQueries,
    replyToSupportQuery,
    editReply,
    deleteReply,
    updateQueryStatus,
  };
};