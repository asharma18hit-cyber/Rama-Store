import axios from 'axios';

// Base URL of the deployed Flask application on Render
export const BASE_URL = 'https://rama-store-3u49.onrender.com';

const client = axios.create({
  baseURL: BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
  withCredentials: true, // Crucial for automatic session cookie handling on mobile
});

export default client;
