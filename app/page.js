import { cacheLife } from 'next/cache';

export default async function Page() {
  'use cache';
  cacheLife('short');
  return (
    <main>
      <img src="https://example.com/hero.webp" fetchPriority="high" alt="" />
      <p>rendered at {new Date().toISOString()}</p>
    </main>
  );
}
