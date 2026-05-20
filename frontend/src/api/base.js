const getApiBaseUrl = () => {
  if (import.meta.env.PROD) return "/api";
  return "/api";
};

export default getApiBaseUrl();
