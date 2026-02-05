const friendController = require('../src/controllers/friendController');

jest.mock('../src/models/user', () => ({
  findById: jest.fn(),
  findOne: jest.fn(),
}));

jest.mock('../src/models/friendRequest', () => ({
  findOne: jest.fn(),
  findById: jest.fn(),
  create: jest.fn(),
  deleteMany: jest.fn(),
}));

const User = require('../src/models/user');
const FriendRequest = require('../src/models/friendRequest');

const mockRes = () => {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res;
};

describe('friendController', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  test('sendFriendRequest returns 404 when target not found', async () => {
    User.findById.mockResolvedValueOnce({ _id: 'u1', friends: [], blockedUsers: [] });
    User.findOne.mockResolvedValueOnce(null);

    const req = {
      user: { _id: 'u1' },
      body: { query: 'missing@example.com' },
    };
    const res = mockRes();
    await friendController.sendFriendRequest(req, res);

    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith({ error: 'User not found' });
  });

  test('sendFriendRequest prevents self request', async () => {
    User.findById.mockResolvedValueOnce({ _id: 'u1', friends: [], blockedUsers: [] });
    User.findOne.mockResolvedValueOnce({ _id: 'u1' });

    const req = {
      user: { _id: 'u1' },
      body: { query: 'me@example.com' },
    };
    const res = mockRes();
    await friendController.sendFriendRequest(req, res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith({ error: 'You cannot add yourself' });
  });

  test('acceptFriendRequest rejects when not recipient', async () => {
    FriendRequest.findById.mockResolvedValueOnce({
      _id: 'r1',
      status: 'pending',
      to: 'u2',
      from: 'u1',
      save: jest.fn(),
    });

    const req = {
      user: { _id: 'u3' },
      params: { requestId: 'r1' },
    };
    const res = mockRes();
    await friendController.acceptFriendRequest(req, res);

    expect(res.status).toHaveBeenCalledWith(403);
    expect(res.json).toHaveBeenCalledWith({ error: 'Not allowed' });
  });
});
