// App URLs, read at run time so one build can serve any society.
// Order: window.OAS_CONFIG (set by /api/config.js from the server),
// then REACT_APP_* build-time env (local dev), then derived from the
// current host by swapping its first label for server, admin or www.

const runtime = (typeof window !== "undefined" && window.OAS_CONFIG) || {};

const derive = (label) => {
  if (typeof window === "undefined") {
    return undefined;
  }
  const { protocol, hostname, port } = window.location;
  const parts = hostname.split(".");
  if (parts.length < 2 || /^[\d.]+$/.test(hostname)) {
    return window.location.origin;
  }
  parts[0] = label;
  return `${protocol}//${parts.join(".")}${port ? `:${port}` : ""}`;
};

export const serverUrl =
  runtime.serverUrl || process.env.REACT_APP_SERVER_URL || derive("server");
export const adminUrl =
  runtime.adminUrl || process.env.REACT_APP_ADMIN_URL || derive("admin");
export const publicUrl =
  runtime.publicUrl || process.env.REACT_APP_PUBLIC_URL || derive("www");
