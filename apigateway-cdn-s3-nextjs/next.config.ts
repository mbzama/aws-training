import type { NextConfig } from 'next'

const nextConfig: NextConfig = {
  reactStrictMode: true,
  output: 'export', // Static export for S3 hosting
  trailingSlash: true, // Required for S3 static hosting
  basePath: '', // No basePath for S3 root deployment
  images: {
    unoptimized: true, // Required for static export
    remotePatterns: [
      {
        protocol: 'https',
        hostname: '**',
      },
    ],
  },
}

export default nextConfig
