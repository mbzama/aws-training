// CloudFront Function for URL rewriting
// This function handles SPA (Single Page Application) routing
// by rewriting requests to non-existent files back to index.html

function handler(event) {
    var request = event.request;
    var uri = request.uri;

    // If the request is for a static asset (has file extension), allow it through
    if (uri.match(/\.[a-z0-9]+$/i)) {
        return request;
    }

    // If the request is for root or has a trailing slash, allow it
    if (uri === '/' || uri.endsWith('/')) {
        return request;
    }

    // If the request is for api routes (_next/api), let it through
    if (uri.startsWith('/_next/api/')) {
        return request;
    }

    // For all other requests (SPA routes), rewrite to index.html
    // This allows client-side routing to handle the request
    request.uri = '/index.html';
    return request;
}
