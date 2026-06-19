import api from './api';

export const getConversations = async () => {
  const { data } = await api.get('/messages/conversations');
  return data;
};

export const createConversation = async (request) => {
  const { data } = await api.post('/messages/conversations', request);
  return data;
};

export const getMessages = async (conversationId, page = 1) => {
  const { data } = await api.get(`/messages/conversations/${conversationId}/messages?page=${page}`);
  return data;
};

export const sendMessage = async (conversationId, content) => {
  const { data } = await api.post(`/messages/conversations/${conversationId}/messages`, { content });
  return data;
};

export const markAsRead = async (conversationId) => {
  await api.post(`/messages/conversations/${conversationId}/read`);
};
