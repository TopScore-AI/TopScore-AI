'use client';
import type { Metadata } from 'next';
import Nav from '@/components/Nav';
import Footer from '@/components/Footer';
import JsonLd from '@/components/JsonLd';
import Image from 'next/image';
import { motion, AnimatePresence } from 'framer-motion';
import { Sparkles, CheckCircle2, ShieldCheck, Zap, Gift, Copy } from 'lucide-react';
import { useEffect, useState } from 'react';
import { useSearchParams } from 'next/navigation';

const schema = {
    '@context': 'https://schema.org',
    '@type': 'WebPage',
    name: 'Download TopScore AI | Free',
    url: 'https://topscoreapp.ai/download',
    description: 'Download TopScore AI free on Android or iOS. AI tutor, CBC & KCSE study resources, and smart study tools.',
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
    const searchParams = useSearchParams();
    const [referralCode, setReferralCode] = useState<string | null>(null);

    useEffect(() => {
        const code = searchParams.get('ref') || localStorage.getItem('ts_referral_code');
        if (code) {
            setReferralCode(code);
            localStorage.setItem('ts_referral_code', code);

            // Track referral landing
            if (typeof window !== 'undefined' && (window as any).gtag) {
                (window as any).gtag('event', 'referral_landing', {
                    'referral_code': code
                });
            }
        }
    }, [searchParams]);

    return (
        <main className="min-h-screen bg-white">
            <JsonLd data={schema} />
            <Nav />
            
            <div className="pt-40 pb-32">
                <div className="max-w-7xl mx-auto px-4 sm:px-10">
                    <div className="grid lg:grid-cols-2 gap-20 items-center">
                        <motion.div
                            initial={{ opacity: 0, x: -30 }}
                            animate={{ opacity: 1, x: 0 }}
                            transition={{ duration: 0.8 }}
                        >
                            <div className="inline-flex items-center gap-2 px-3 py-1 bg-brand-primary/10 rounded-full text-[10px] font-bold uppercase tracking-widest mb-8 border border-brand-primary/20 text-brand-primary">
                                <Sparkles className="w-3.5 h-3.5" />
                                Available Now
                            </div>
                            <AnimatePresence>
                                {referralCode && (
                                    <motion.div
                                        initial={{ opacity: 0, y: -10 }}
                                        animate={{ opacity: 1, y: 0 }}
                                        className="mb-6 p-4 bg-emerald-50 border border-emerald-100 rounded-2xl flex items-center gap-4"
                                    >
                                        <div className="w-10 h-10 bg-emerald-500 text-white rounded-full flex items-center justify-center shrink-0 shadow-lg shadow-emerald-200">
                                            <Gift className="w-5 h-5" />
                                        </div>
                                        <div>
                                            <p className="text-sm font-bold text-emerald-900">Referral Reward Active!</p>
                                            <p className="text-xs text-emerald-700 font-medium">Use code <span className="font-black underline">{referralCode}</span> in the app for 500 bonus XP.</p>
                                        </div>
                                    </motion.div>
                                )}
                            </AnimatePresence>

                            <h1 className="text-5xl md:text-7xl font-sans font-black text-slate-900 tracking-tighter mb-8 leading-[1.05]">
                                Your AI Tutor, <br /> in your pocket.
                            </h1>
                            <p className="text-slate-500 text-xl leading-relaxed mb-12 font-medium max-w-lg">
                                Master CBC, 8-4-4, and IGCSE from anywhere. Download the mobile app to access your full resource library and AI tutor even when offline.
                            </p>

                            <div className="flex flex-wrap gap-4 mb-16">
                                <a
                                    href="https://play.google.com/store/apps/details?id=com.topscoreapp.ai"
                                    onClick={() => {
                                        if (typeof window !== 'undefined' && (window as any).gtag) {
                                            (window as any).gtag('event', 'download_click', { 'platform': 'android' });
                                        }
                                    }}
                                    className="transition-transform hover:scale-105 active:scale-95"
                                >
                                    <Image
                                        src="/GetItOnGooglePlay_Badge_Web_color_English.svg"
                                        alt="Get it on Google Play"
                                        width={180}
                                        height={53}
                                        className="h-14 w-auto"
                                    />
                                </a>
                                <a
                                    href="https://apps.apple.com/app/topscore-ai/id6476140411"
                                    onClick={() => {
                                        if (typeof window !== 'undefined' && (window as any).gtag) {
                                            (window as any).gtag('event', 'download_click', { 'platform': 'ios' });
                                        }
                                    }}
                                    className="transition-transform hover:scale-105 active:scale-95"
                                >
                                    <Image
                                        src="/app-store-badge.svg"
                                        alt="Download on the App Store"
                                        width={180}
                                        height={53}
                                        className="h-14 w-auto"
                                    />
                                </a>
                            </div>

                            <div className="grid sm:grid-cols-2 gap-6">
                                {[
                                    { icon: <ShieldCheck className="w-5 h-5 text-emerald-500" />, text: "Verified Educational Content" },
                                    { icon: <Zap className="w-5 h-5 text-amber-500" />, text: "Zero Lag AI Interaction" },
                                    { icon: <CheckCircle2 className="w-5 h-5 text-indigo-500" />, text: "Offline Resource Sync" },
                                    { icon: <Sparkles className="w-5 h-5 text-purple-500" />, text: "National Rank Tracking" }
                                ].map((item, i) => (
                                    <div key={i} className="flex items-center gap-3">
                                        <div className="p-2 bg-slate-50 rounded-lg border border-slate-100">
                                            {item.icon}
                                        </div>
                                        <span className="text-sm font-bold text-slate-700">{item.text}</span>
                                    </div>
                                ))}
                            </div>
                        </motion.div>

                        <motion.div
                            initial={{ opacity: 0, scale: 0.9 }}
                            animate={{ opacity: 1, scale: 1 }}
                            transition={{ duration: 1 }}
                            className="relative"
                        >
                            <div className="absolute inset-0 bg-gradient-to-tr from-brand-primary/20 to-indigo-500/20 blur-3xl rounded-full" />
                            <div className="relative bg-slate-900 rounded-[3rem] p-4 shadow-2xl border border-slate-800 transform rotate-2 hover:rotate-0 transition-transform duration-700">
                                <div className="bg-white rounded-[2.5rem] overflow-hidden">
                                    <img 
                                        src="/topscore_app_mockup.png" 
                                        alt="TopScore AI Mobile App" 
                                        className="w-full h-auto"
                                    />
                                </div>
                            </div>
                        </motion.div>
                    </div>
                </div>
            </div>

            <Footer />
        </main>
    );
}
