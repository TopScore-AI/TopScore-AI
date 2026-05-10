import type { Metadata } from 'next';
import Nav from '@/components/Nav';
import Tools from '@/components/Tools';
import Footer from '@/components/Footer';
import JsonLd from '@/components/JsonLd';

export const metadata: Metadata = {
    title: 'Study Tools',
    description:
        '8 built-in study tools in TopScore AI: Smart Scanner, Scientific Calculator, Virtual Science Lab, Interactive Periodic Table, AI Flashcard Generator, Timetable, Global Search, and PDF Viewer.',
    openGraph: {
        title: 'Study Tools — TopScore AI',
        description: '8 built-in tools: scanner, calculator, science lab, periodic table, flashcards, timetable, search & PDF viewer.',
        url: 'https://topscoreapp.ai/tools',
        images: [{ url: '/og-image.png', width: 1200, height: 630 }],
    },
    alternates: { canonical: 'https://topscoreapp.ai/tools' },
};

const schema = {
    '@context': 'https://schema.org',
    '@type': 'WebPage',
    name: 'Study Tools | TopScore AI',
    url: 'https://topscoreapp.ai/tools',
    description: metadata.description,
    isPartOf: { '@id': 'https://topscoreapp.ai/#website' },
    mainEntity: {
        '@type': 'ItemList',
        name: 'TopScore AI Study Tools',
        itemListElement: [
            'Smart Scanner', 'Scientific Calculator', 'Science Lab',
            'Periodic Table', 'Flashcard Generator', 'Timetable',
            'Global Search', 'PDF Viewer',
        ].map((name, i) => ({
            '@type': 'ListItem',
            position: i + 1,
            name,
        })),
    }
};

export default function ToolsPage() {
    return (
        <main className="min-h-screen">
            <JsonLd data={schema} />
            <Nav />
            <div className="container mx-auto px-4 pt-32">
                <Tools />
            </div>
            <Footer />
        </main>
    );
}
