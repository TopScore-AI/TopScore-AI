import type { Metadata } from 'next';
import Nav from '@/components/Nav';
import CtaBanner from '@/components/CtaBanner';
import Footer from '@/components/Footer';
import JsonLd from '@/components/JsonLd';
import Breadcrumbs from '@/components/Breadcrumbs';

export const metadata: Metadata = {
    title: 'Download TopScore AI — Free',
    description:
        'Download TopScore AI free on Android or iOS. AI tutor, CBC & KCSE study resources, offline mode, and smart study tools — all free, no credit card required.',
    openGraph: {
        title: 'Download TopScore AI — Free on Android & iOS',
        description: 'Get TopScore AI free. No credit card required. Available on Google Play and the App Store.',
        url: 'https://topscoreapp.ai/download',
        images: [{ url: '/og-image.png', width: 1200, height: 630 }],
    },
    alternates: { canonical: 'https://topscoreapp.ai/download' },
};

const schema = {
    '@context': 'https://schema.org',
    '@type': 'WebPage',
    name: 'Download TopScore AI | Free',
    url: 'https://topscoreapp.ai/download',
    description: metadata.description,
    isPartOf: { '@id': 'https://topscoreapp.ai/#website' },
    mainEntity: {
        '@type': 'MobileApplication',
        name: 'TopScore AI',
        operatingSystem: 'Android, iOS',
        applicationCategory: 'EducationApplication',
        offers: { '@type': 'Offer', price: '0', priceCurrency: 'KES' },
        downloadUrl: 'https://topscoreapp.ai/download',
    }
};

export default function DownloadPage() {
    return (
        <main className="bg-black min-h-screen text-white">
            <JsonLd data={schema} />
            <Nav />
            <div className="container mx-auto px-4 pt-32 pb-20">
                <Breadcrumbs items={[{ label: 'Download' }]} />
                <CtaBanner />
            </div>
            <Footer />
        </main>
    );
}

