import { encode as base64Encode } from 'https://deno.land/std@0.177.0/encoding/base64.ts'

interface FCMMessage {
  token: string
  title: string
  body: string
  data?: Record<string, string>
  imageUrl?: string
}

interface FCMResponse {
  success: boolean
  messageId?: string
  error?: string
}

interface ServiceAccountKey {
  type: string
  project_id: string
  private_key_id: string
  private_key: string
  client_email: string
  client_id: string
  auth_uri: string
  token_uri: string
  auth_provider_x509_cert_url: string
  client_x509_cert_url: string
}

function base64UrlEncode(data: Uint8Array): string {
  return base64Encode(data)
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '')
}

async function createJWT(serviceAccount: ServiceAccountKey): Promise<string> {
  const header = {
    alg: 'RS256',
    typ: 'JWT'
  }
  
  const now = Math.floor(Date.now() / 1000)
  const payload = {
    iss: serviceAccount.client_email,
    sub: serviceAccount.client_email,
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
    scope: 'https://www.googleapis.com/auth/firebase.messaging'
  }
  
  const encoder = new TextEncoder()
  const headerB64 = base64UrlEncode(encoder.encode(JSON.stringify(header)))
  const payloadB64 = base64UrlEncode(encoder.encode(JSON.stringify(payload)))
  const signatureInput = `${headerB64}.${payloadB64}`
  
  const privateKeyPem = serviceAccount.private_key
  const pemContents = privateKeyPem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '')
  
  const binaryKey = Uint8Array.from(atob(pemContents), c => c.charCodeAt(0))
  
  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    binaryKey,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign']
  )
  
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    encoder.encode(signatureInput)
  )
  
  const signatureB64 = base64UrlEncode(new Uint8Array(signature))
  
  return `${signatureInput}.${signatureB64}`
}

async function getAccessToken(serviceAccount: ServiceAccountKey): Promise<string> {
  const jwt = await createJWT(serviceAccount)
  
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt
    })
  })
  
  if (!response.ok) {
    const error = await response.text()
    throw new Error(`Failed to get access token: ${error}`)
  }
  
  const data = await response.json()
  return data.access_token
}

function getServiceAccount(): ServiceAccountKey {
  const serviceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')
  
  if (serviceAccountJson) {
    try {
      return JSON.parse(serviceAccountJson)
    } catch {
      console.log('FIREBASE_SERVICE_ACCOUNT is not valid JSON, trying individual env vars')
    }
  }
  
  const projectId = Deno.env.get('FCM_PROJECT_ID') || 'caremind-29a5d'
  const privateKey = Deno.env.get('FCM_PRIVATE_KEY') || ''
  const clientEmail = Deno.env.get('FCM_CLIENT_EMAIL') || ''
  
  if (!privateKey || !clientEmail) {
    throw new Error('FCM credentials not configured. Set FIREBASE_SERVICE_ACCOUNT or FCM_PRIVATE_KEY + FCM_CLIENT_EMAIL')
  }
  
  const formattedPrivateKey = privateKey.includes('-----BEGIN') 
    ? privateKey 
    : `-----BEGIN PRIVATE KEY-----\n${privateKey}\n-----END PRIVATE KEY-----\n`
  
  return {
    type: 'service_account',
    project_id: projectId,
    private_key_id: '',
    private_key: formattedPrivateKey.replace(/\\n/g, '\n'),
    client_email: clientEmail,
    client_id: '',
    auth_uri: 'https://accounts.google.com/o/oauth2/auth',
    token_uri: 'https://oauth2.googleapis.com/token',
    auth_provider_x509_cert_url: 'https://www.googleapis.com/oauth2/v1/certs',
    client_x509_cert_url: `https://www.googleapis.com/robot/v1/metadata/x509/${encodeURIComponent(clientEmail)}`
  }
}

let cachedToken: { token: string; expiry: number } | null = null

async function getOrRefreshToken(): Promise<string> {
  const now = Date.now()
  
  if (cachedToken && cachedToken.expiry > now + 60000) {
    return cachedToken.token
  }
  
  const serviceAccount = getServiceAccount()
  const token = await getAccessToken(serviceAccount)
  
  cachedToken = {
    token,
    expiry: now + 3500000
  }
  
  return token
}

export async function sendFCMNotification(message: FCMMessage): Promise<FCMResponse> {
  try {
    const serviceAccount = getServiceAccount()
    const accessToken = await getOrRefreshToken()
    
    const fcmPayload: Record<string, unknown> = {
      message: {
        token: message.token,
        notification: {
          title: message.title,
          body: message.body,
        },
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
            channel_id: 'caremind_notifications'
          }
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
              'content-available': 1
            }
          }
        },
        webpush: {
          notification: {
            icon: '/icons/icon-192x192.png',
            badge: '/icons/badge-72x72.png'
          }
        }
      }
    }
    
    if (message.data) {
      (fcmPayload.message as Record<string, unknown>).data = message.data
    }
    
    if (message.imageUrl) {
      const notification = (fcmPayload.message as Record<string, unknown>).notification as Record<string, string>
      notification.image = message.imageUrl
    }
    
    const response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(fcmPayload)
      }
    )
    
    const responseData = await response.json()
    
    if (!response.ok) {
      console.error('FCM Error:', responseData)
      return {
        success: false,
        error: responseData.error?.message || JSON.stringify(responseData)
      }
    }
    
    return {
      success: true,
      messageId: responseData.name
    }
  } catch (error) {
    console.error('FCM Exception:', error)
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error'
    }
  }
}

export async function sendFCMToMultiple(tokens: string[], title: string, body: string, data?: Record<string, string>): Promise<{ sent: number; failed: number; errors: string[] }> {
  const results = await Promise.allSettled(
    tokens.map(token => sendFCMNotification({ token, title, body, data }))
  )
  
  let sent = 0
  let failed = 0
  const errors: string[] = []
  
  results.forEach((result, index) => {
    if (result.status === 'fulfilled' && result.value.success) {
      sent++
    } else {
      failed++
      const error = result.status === 'rejected' 
        ? result.reason 
        : result.value.error
      errors.push(`Token ${index}: ${error}`)
    }
  })
  
  return { sent, failed, errors }
}
