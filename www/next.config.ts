import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  images: {
    // Sites serves static output without a Next image-optimisation binding.
    // Critical responsive images are generated at build time in /public.
    unoptimized: true,
  },
};

export default nextConfig;
