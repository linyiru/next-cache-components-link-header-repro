/** @type {import('next').NextConfig} */
module.exports = {
  cacheComponents: true,
  // Workaround: uncomment to stop React's onHeaders from emitting a Link header,
  // which stops the duplication.
  // reactMaxHeadersLength: 0,
  cacheLife: {
    short: { stale: 300, revalidate: 2, expire: 3600 },
  },
  async headers() {
    return [
      {
        source: '/',
        headers: [{ key: 'Link', value: '</llms.txt>; rel="llms-txt"' }],
      },
    ];
  },
};
