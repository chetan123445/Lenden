const Transaction = require('../models/transaction');

const ADMIN_TRANSACTION_SORT_FIELDS = new Set([
  'amount',
  'currency',
  'date',
  'time',
  'place',
  'interestType',
  'interestRate',
  'expectedReturnDate',
  'counterpartyEmail',
  'userEmail',
  'role',
  'userCleared',
  'counterpartyCleared',
  'remainingAmount',
  'totalAmountWithInterest',
  'isPartiallyPaid',
  'createdAt',
  'updatedAt',
]);

const escapeRegex = (value = '') => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

const parsePositiveInteger = (value) => {
  const parsed = parseInt(value, 10);
  if (Number.isNaN(parsed) || parsed <= 0) return null;
  return parsed;
};

const buildAdminTransactionFilter = (query = {}) => {
  const {
    q,
    currency,
    role,
    interestType,
    userEmail,
    counterpartyEmail,
    isPartiallyPaid,
  } = query;

  const filter = {};

  if (currency && currency !== 'All') {
    filter.currency = currency;
  }

  if (role && role !== 'All') {
    filter.role = role;
  }

  if (interestType && interestType !== 'All') {
    filter.interestType = interestType;
  }

  if (typeof isPartiallyPaid === 'string' && isPartiallyPaid !== 'All') {
    filter.isPartiallyPaid = isPartiallyPaid === 'true';
  }

  if (userEmail) {
    filter.userEmail = { $regex: escapeRegex(userEmail), $options: 'i' };
  }

  if (counterpartyEmail) {
    filter.counterpartyEmail = {
      $regex: escapeRegex(counterpartyEmail),
      $options: 'i',
    };
  }

  if (q && q.trim()) {
    const searchRegex = new RegExp(escapeRegex(q.trim()), 'i');
    filter.$or = [
      { transactionId: searchRegex },
      { place: searchRegex },
      { currency: searchRegex },
      { role: searchRegex },
      { description: searchRegex },
      { userEmail: searchRegex },
      { counterpartyEmail: searchRegex },
    ];
  }

  return filter;
};

const normalizeAdminTransactionUpdate = (payload = {}) => {
  const allowedPaths = new Set(
    Object.keys(Transaction.schema.paths).filter(
      (path) => !['_id', '__v', 'createdAt', 'updatedAt'].includes(path)
    )
  );

  const normalized = {};

  for (const [key, value] of Object.entries(payload)) {
    if (!allowedPaths.has(key)) continue;

    if (['date', 'expectedReturnDate'].includes(key)) {
      normalized[key] = value ? new Date(value) : null;
      continue;
    }

    normalized[key] = value;
  }

  if (
    Object.prototype.hasOwnProperty.call(normalized, 'amount') &&
    !Object.prototype.hasOwnProperty.call(normalized, 'remainingAmount') &&
    normalized.isPartiallyPaid !== true
  ) {
    normalized.remainingAmount = normalized.amount;
  }

  if (
    Object.prototype.hasOwnProperty.call(normalized, 'amount') &&
    !Object.prototype.hasOwnProperty.call(normalized, 'totalAmountWithInterest')
  ) {
    const nextInterestType = normalized.interestType;
    const nextInterestRate = normalized.interestRate;
    if (
      nextInterestType === 'none' ||
      nextInterestType == null ||
      nextInterestRate == null
    ) {
      normalized.totalAmountWithInterest = normalized.amount;
    }
  }

  return normalized;
};

const getAllTransactions = async (req, res) => {
  try {
    const { page, limit, sortBy = 'date', order = 'desc' } = req.query;
    const sortField = ADMIN_TRANSACTION_SORT_FIELDS.has(sortBy)
      ? sortBy
      : 'date';
    const sortOrder = order === 'asc' ? 1 : -1;
    const pageNumber = parsePositiveInteger(page) || 1;
    const limitNumber = parsePositiveInteger(limit);
    const filter = buildAdminTransactionFilter(req.query);

    let query = Transaction.find(filter).sort({ [sortField]: sortOrder, _id: -1 });

    if (limitNumber) {
      query = query.skip((pageNumber - 1) * limitNumber).limit(limitNumber);
    }

    const transactions = await query;
    const totalTransactions = await Transaction.countDocuments(filter);

    res.json({
      success: true,
      transactions,
      totalTransactions,
      totalPages: limitNumber ? Math.ceil(totalTransactions / limitNumber) : 1,
      currentPage: pageNumber,
    });
  } catch (error) {
    console.error('Error fetching transactions:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch transactions',
    });
  }
};

const updateTransaction = async (req, res) => {
  try {
    const { transactionId } = req.params;
    
    let body = { ...req.body };
    const isMultipart = req.is('multipart/form-data');

    if (isMultipart) {
      for (const key in body) {
        if (body[key] === 'true') {
          body[key] = true;
        } else if (body[key] === 'false') {
          body[key] = false;
        } else if (
          typeof body[key] === 'string' &&
          (body[key].startsWith('{') || body[key].startsWith('['))
        ) {
          try {
            body[key] = JSON.parse(body[key]);
          } catch (e) {
            // Not a valid JSON string, leave as is
          }
        }
      }
    }
    
    // When photos are uploaded, they might come as separate fields.
    // Multer's `any()` should handle this. If `photos` is still a string, parse it.
    if (body.photos && typeof body.photos === 'string') {
      try {
        body.photos = JSON.parse(body.photos)
      } catch(e) {
        // if it's not a json array, maybe it's a single photo. wrap it in an array
        body.photos = [body.photos];
      }
    }


    const updateData = normalizeAdminTransactionUpdate(body);
    const transaction = await Transaction.findById(transactionId);

    if (!transaction) {
      return res.status(404).json({
        success: false,
        message: 'Transaction not found',
      });
    }

    Object.assign(transaction, updateData);
    await transaction.save();

    res.json({
      success: true,
      message: 'Transaction updated successfully',
      transaction,
    });
  } catch (error) {
    console.error('Error updating transaction:', error);
    res.status(error.name === 'ValidationError' ? 400 : 500).json({
      success: false,
      message:
        error.name === 'ValidationError'
          ? error.message
          : 'Failed to update transaction',
    });
  }
};

const deleteTransaction = async (req, res) => {
  try {
    const { transactionId } = req.params;
    const transaction = await Transaction.findByIdAndDelete(transactionId);

    if (!transaction) {
      return res.status(404).json({
        success: false,
        message: 'Transaction not found',
      });
    }

    res.json({
      success: true,
      message: 'Transaction deleted successfully',
    });
  } catch (error) {
    console.error('Error deleting transaction:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to delete transaction',
    });
  }
};

module.exports = {
  getAllTransactions,
  updateTransaction,
  deleteTransaction,
};
