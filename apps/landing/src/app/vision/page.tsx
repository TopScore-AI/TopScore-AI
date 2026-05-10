import type { Metadata } from 'next';
import Nav from '@/components/Nav';
import Footer from '@/components/Footer';
import { Sparkles, Target, Eye, Globe } from 'lucide-react';
import { motion } from 'framer-motion';

export const metadata: Metadata = {
    title: 'Our Vision — TopScore AI',
    description: 'Empowering the next generation of African scholars with personalized AI tutoring and enterprise-grade educational tools.',
};

export default function VisionPage() {
    return (
        <main className="min-h-screen bg-white">
            <Nav />
            
            <div className="pt-40 pb-24 max-w-7xl mx-auto px-4 sm:px-10">
                <div className="text-center mb-20">
                    <h2 className="text-sm font-bold text-brand-primary uppercase tracking-[0.25em] mb-6">Our Mission</h2>
                    <h1 className="text-5xl md:text-7xl font-sans font-black text-slate-900 tracking-tighter mb-8 leading-tight">
                        Democratizing Elite <br /> Education for Africa.
                    </h1>
                    <p className="text-slate-500 max-w-2xl mx-auto text-xl leading-relaxed font-medium">
                        At TopScore AI, we believe that world-class 1-on-1 tutoring shouldn't be a privilege of the few. We're building the infrastructure to make personalized learning accessible to every student in Kenya and beyond.
                    </p>
                </div>

                <div className="grid md:grid-cols-3 gap-8 mb-32">
                    {[
                        {
                            icon: <Target className="w-8 h-8" />,
                            title: "Precision Learning",
                            desc: "Using Gemini Multimodal AI to understand exactly where a student struggles and providing step-by-step guidance."
                        },
                        {
                            icon: <Eye className="w-8 h-8" />,
                            title: "Local Grounding",
                            desc: "Ensuring our AI is deeply rooted in the Kenyan curriculum (CBC, 8-4-4) and vetted educational materials."
                        },
                        {
                            icon: <Globe className="w-8 h-8" />,
                            title: "Scalable Impact",
                            desc: "Building lightweight, offline-capable tools that work on any device, from Nairobi to the most remote regions."
                        }
                    ].map((item, i) => (
                        <div key={i} className="bg-slate-50 p-10 rounded-[2.5rem] border border-slate-100 hover:bg-white hover:shadow-2xl hover:shadow-indigo-50 transition-all duration-500">
                            <div className="w-16 h-16 bg-white rounded-2xl flex items-center justify-center text-brand-primary mb-10 shadow-sm border border-slate-100">
                                {item.icon}
                            </div>
                            <h4 className="text-2xl font-sans font-black text-slate-900 tracking-tight mb-4">{item.title}</h4>
                            <p className="text-slate-500 leading-relaxed font-medium">{item.desc}</p>
                        </div>
                    ))}
                </div>

                <div className="bg-slate-900 rounded-[3.5rem] p-12 md:p-20 text-white relative overflow-hidden">
                    <div className="absolute inset-0 bg-[radial-gradient(circle_at_70%_30%,rgba(79,70,229,0.2),transparent_70%)]" />
                    <div className="relative z-10 max-w-3xl">
                        <div className="inline-flex items-center gap-2 px-3 py-1 bg-white/10 rounded-full text-[10px] font-bold uppercase tracking-widest mb-8 border border-white/10 text-indigo-400">
                            <Sparkles className="w-3.5 h-3.5" />
                            Future-Proofing
                        </div>
                        <h2 className="text-4xl md:text-6xl font-sans font-black mb-8 leading-tight tracking-tight">
                            The next billion scholars start here.
                        </h2>
                        <p className="text-slate-400 text-xl leading-relaxed mb-12">
                            We are not just building an app; we are building a cognitive partner for the next generation. Join us as we redefine what's possible in African education.
                        </p>
                        <a href="mailto:admin@topscoreapp.ai" className="bg-white text-slate-900 px-8 py-4 rounded-2xl font-bold text-lg hover:bg-brand-primary hover:text-white transition-all shadow-xl">
                            Partner With Us
                        </a>
                    </div>
                </div>
            </div>

            <Footer />
        </main>
    );
}
