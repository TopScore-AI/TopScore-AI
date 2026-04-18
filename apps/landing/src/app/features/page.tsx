import type { Metadata } from 'next';
import Nav from '@/components/Nav';
import Features from '@/components/Features';
import ActiveVoiceShowcase from '@/components/ActiveVoiceShowcase';
import CompositionShowcase from '@/components/CompositionShowcase';
import Personalization from '@/components/Personalization';
import Footer from '@/components/Footer';
import JsonLd from '@/components/JsonLd';

export const metadata: Metadata = {
    title: 'Features',
    description:
        'Explore TopScore AI features: AI Tutor available 24/7, full CBC & KCSE resource library, daily streak tracker, smart study reports, offline mode, and real-time global search.',
    openGraph: {
        title: 'Features — TopScore AI',
        description: 'AI Tutor, resource library, streaks, study reports, offline mode, and global search — all in one app.',
        url: 'https://topscore-ai.com/features',
        images: [{ url: '/og-image.png', width: 1200, height: 630 }],
    },
    alternates: { canonical: 'https://topscoreapp.ai/features' },
};

const schema = {
    '@context': 'https://schema.org',
    '@type': 'WebPage',
    name: 'Features | TopScore AI',
    url: 'https://topscoreapp.ai/features',
    description: metadata.description,
    alternates: { canonical: 'https://topscoreapp.ai/features' },
    openGraph: {
        url: 'https://topscoreapp.ai/features',
    },
    isPartOf: { '@id': 'https://topscoreapp.ai/#website' },
};

export default function FeaturesPage() {
    return (
        <main>
            <JsonLd data={schema} />
            <Nav />
            <div className="container mx-auto px-4 pt-32 space-y-24 pb-20">
                <Features />
                <ActiveVoiceShowcase />
                <Personalization />
                <CompositionShowcase />
            </div>
            <Footer />
        </main>
    );
}

