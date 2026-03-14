import { environment } from '../environments/environment';

/**
 * Detects if the application is running on the development port
 * The Force reveals the true nature of our server!
 */
function isDevPort(): boolean {
    if (typeof window !== 'undefined' && window.location) {
        return window.location.port === '4200';
    }
    return false;
}

/**
 * Returns the appropriate base address for API calls and WebSocket connections
 * The Force guides this function to always return the correct path!
 */
export function getBaseAddress(): string {
    // Check if we're in a browser environment
    if (typeof window === 'undefined') {
        // SSR or non-browser environment
        return environment.baseUrl || '';
    }

    // Dynamic detection based on port
    if (isDevPort()) {
        // Running on Angular dev server (port 4200)
        return environment.baseUrl;
    }

    // Running on any other port (including production)
    // Empty string allows relative URLs to work automatically
    return '';
}

/**
 * Returns the frontend server address
 * Useful for CORS configuration and redirects
 */
export function getFrontServerAddress(): string {
    if (typeof window !== 'undefined') {
        return `${window.location.protocol}//${window.location.host}`;
    }
    // Fallback for SSR or non-browser environments
    return 'http://localhost:4200';
}

/**
 * Returns the API base URL
 * May the Force be with your API calls!
 */
export function getApiUrl(): string {
    const baseAddress = getBaseAddress();
    return baseAddress ? `${baseAddress}/api` : '/api';
}

/**
 * Returns the WebSocket URL for Socket.io connections
 * The Force flows through these real-time connections!
 */
export function getWebSocketUrl(): string {
    if (typeof window === 'undefined') {
        // SSR fallback
        return environment.production ? '' : 'http://localhost:3000';
    }

    if (isDevPort()) {
        // Development mode on port 4200
        return 'http://localhost:3000';
    }

    // Production or other environments - use current host
    return `${window.location.protocol}//${window.location.host}`;
}

/**
 * Check if we're running in production mode
 */
export function isProduction(): boolean {
    return environment.production;
}

/**
 * Check if we're running on the development server
 */
export function isDevelopmentServer(): boolean {
    return isDevPort();
}

/**
 * Get the current port number
 */
export function getCurrentPort(): string {
    if (typeof window !== 'undefined' && window.location) {
        return window.location.port || (window.location.protocol === 'https:' ? '443' : '80');
    }
    return '';
}

/**
 * Log the current configuration (for debugging)
 * The Force reveals all paths!
 */
export function logConfiguration(): void {
    console.log('🌟 Base Address Configuration:');
    console.log('  Production Mode:', isProduction());
    console.log('  Current Port:', getCurrentPort());
    console.log('  Is Dev Server (4200):', isDevelopmentServer());
    console.log('  Base Address:', getBaseAddress());
    console.log('  API URL:', getApiUrl());
    console.log('  WebSocket URL:', getWebSocketUrl());
    console.log('  Frontend Address:', getFrontServerAddress());
}