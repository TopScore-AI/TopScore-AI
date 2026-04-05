import type { Metadata } from 'next';
import Nav from '@/components/Nav';
import Pricing from '@/components/Pricing';
import Footer from '@/components/Footer';
import JsonLd from '@/components/JsonLd';
import Breadcrumbs from '@/components/Breadcrumbs';

export const metadata: Metadata = {
    title: 'Pricing',
    description:
        'Start for free and upgrade when ready. TopScore AI offers flexible pricing plans tailored to Kenyan learners.',
    openGraph: {
        title: 'Pricing — TopScore AI',
        description: 'Start for free and upgrade when ready. Flexible pricing plans.',
        url: 'https://topscoreapp.ai/pricing',
        images: [{ url: '/og-image.png', width: 1200, height: 630 }],
    },
    alternates: { canonical: 'https://topscoreapp.ai/pricing' },
};

const schema = {
    '@context': 'https://schema.org',
    '@type': 'WebPage',
    name: 'Pricing | TopScore AI',
    url: 'https://topscoreapp.ai/pricing',
    description: metadata.description,
    alternates: { canonical: 'https://topscoreapp.ai/pricing' },
    openGraph: {
        url: 'https://topscoreapp.ai/pricing',
    },
    isPartOf: { '@id': 'https://topscoreapp.ai/#website' },
};

export default function PricingPage() {
    return (
        <main className="bg-black min-h-screen text-white">
            <JsonLd data={schema} />
            <Nav />
            <div className="container mx-auto px-4 pt-32">
                <Breadcrumbs items={[{ label: 'Pricing' }]} />
                <Pricing />
            </div>
            <Footer />
        </main>
    );
}
