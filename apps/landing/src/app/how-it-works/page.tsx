import type { Metadata } from 'next';
import Nav from '@/components/Nav';
import HowItWorks from '@/components/HowItWorks';
import Footer from '@/components/Footer';
import JsonLd from '@/components/JsonLd';

export const metadata: Metadata = {
    title: 'How It Works',
    description:
        'Get started with TopScore AI in 4 steps: download the app, explore subjects and resources, study with your AI tutor, and build a daily learning streak.',
    openGraph: {
        title: 'How It Works — TopScore AI',
        description: 'Get started in 4 easy steps — free to download, no credit card needed.',
        url: 'https://topscoreapp.ai/how-it-works',
        images: [{ url: '/og-image.png', width: 1200, height: 630 }],
    },
    alternates: { canonical: 'https://topscoreapp.ai/how-it-works' },
};

const schema = {
    '@context': 'https://schema.org',
    '@type': 'WebPage',
    name: 'How It Works | TopScore AI',
    url: 'https://topscoreapp.ai/how-it-works',
    description: metadata.description,
    isPartOf: { '@id': 'https://topscoreapp.ai/#website' },
    mainEntity: {
        '@type': 'HowTo',
        name: 'How to Get Started with TopScore AI',
        step: [
            { '@type': 'HowToStep', position: 1, name: 'Download & Sign Up', text: 'Install TopScore AI and create a free account.' },
            { '@type': 'HowToStep', position: 2, name: 'Explore Subjects & Resources', text: 'Instantly access CBC, 8-4-4, and IGCSE materials.' },
            { '@type': 'HowToStep', position: 3, name: 'Study with AI', text: 'Chat with your AI tutor or browse the resource library.' },
            { '@type': 'HowToStep', position: 4, name: 'Build Your Streak', text: 'Study daily to build streaks and unlock achievements.' },
        ],
    }
};

export default function HowItWorksPage() {
    return (
        <main className="min-h-screen">
            <JsonLd data={schema} />
            <Nav />
            <div className="container mx-auto px-4 pt-32">
                <HowItWorks />
            </div>
            <Footer />
        </main>
    );
}
