const getApiUrl = () => {
  if (import.meta.env.PROD) return "";
  return "";
};

const API = getApiUrl();

export { API };
