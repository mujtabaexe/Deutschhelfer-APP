// Minimal Google Play Developer API client for subscriptions.
//
// Credentials come from the function's service account (Application Default
// Credentials). The owner must grant that account access in Play Console.
// Nothing here runs until PLAY_PACKAGE_NAME is configured.

const BASE = 'https://androidpublisher.googleapis.com/androidpublisher/v3/applications';
const SCOPE = 'https://www.googleapis.com/auth/androidpublisher';

export function createPlayClient({ packageName, getAccessToken, fetchImpl = fetch }) {
  async function call(method, path) {
    const token = await getAccessToken();
    const response = await fetchImpl(`${BASE}/${encodeURIComponent(packageName)}${path}`, {
      method,
      headers: { Authorization: `Bearer ${token}` },
    });
    if (!response.ok) {
      // Do not include the purchase token or response body in errors.
      const error = new Error(`Play API ${method} failed with ${response.status}`);
      error.status = response.status;
      throw error;
    }
    return method === 'GET' ? response.json() : null;
  }

  return {
    getSubscription(purchaseToken) {
      return call('GET', `/purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`);
    },
    acknowledge(productId, purchaseToken) {
      return call(
        'POST',
        `/purchases/subscriptions/${encodeURIComponent(productId)}/tokens/${encodeURIComponent(purchaseToken)}:acknowledge`,
      );
    },
  };
}

export async function defaultAccessToken() {
  const { GoogleAuth } = await import('google-auth-library');
  const auth = new GoogleAuth({ scopes: [SCOPE] });
  const client = await auth.getClient();
  const { token } = await client.getAccessToken();
  if (!token) throw new Error('No access token for the Play Developer API.');
  return token;
}
