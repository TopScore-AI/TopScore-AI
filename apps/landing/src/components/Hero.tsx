'use client';
import { motion } from 'framer-motion';
import { ArrowRight, Sparkles, Play } from 'lucide-react';
import { useLocale } from '@/i18n';

export default function Hero() {
  const { t } = useLocale();

  return (
    <section className="relative pt-20 pb-32 overflow-hidden">
      {/* Background Layers */}
      <div className="absolute inset-0 hero-gradient -z-20" />
      
      {/* Animated Background Elements */}
      <div className="absolute inset-0 -z-10 overflow-hidden pointer-events-none">
        <motion.div 
          animate={{ 
            scale: [1, 1.2, 1],
            opacity: [0.2, 0.5, 0.2],
            rotate: [0, 90, 0],
          }}
          transition={{ duration: 20, repeat: Infinity, ease: "easeInOut" }}
          className="absolute -top-64 -right-64 w-[800px] h-[800px] bg-brand-primary/10 rounded-full blur-[120px]"
        />
        <motion.div 
          animate={{ 
            scale: [1.2, 1, 1.2],
            opacity: [0.1, 0.4, 0.1],
            rotate: [0, -90, 0],
          }}
          transition={{ duration: 25, repeat: Infinity, ease: "easeInOut" }}
          className="absolute -bottom-64 -left-64 w-[700px] h-[700px] bg-indigo-400/10 rounded-full blur-[100px]"
        />
      </div>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-10 relative">
        <div className="flex flex-col items-center text-center max-w-4xl mx-auto gap-10">
          <div className="flex flex-col items-center gap-8">
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              className="inline-flex items-center gap-2 px-4 py-1.5 bg-indigo-50 text-brand-primary rounded-full text-[10px] font-bold uppercase tracking-wider w-fit"
            >
              <span>{t('hero.badge' as any)}</span>
              <div className="w-2 h-2 rounded-full bg-brand-primary animate-pulse" />
            </motion.div>

            <motion.h1
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.7, delay: 0.1, ease: "easeOut" }}
              className="text-7xl md:text-8xl lg:text-[10rem] font-display font-black leading-[0.8] tracking-tight text-slate-900 text-balance"
            >
              {t('hero.h1a' as any)}
              <span className="bg-clip-text text-transparent bg-gradient-to-r from-brand-primary via-indigo-500 to-indigo-400">
                {t('hero.h1Grad' as any)}
              </span>
              <br />
              <span className="text-4xl md:text-6xl text-slate-500 tracking-normal font-bold">
                {t('hero.h1b' as any)}
              </span>
            </motion.h1>


            <motion.p
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.5, delay: 0.2 }}
              className="text-lg md:text-2xl text-slate-600 leading-relaxed max-w-2xl text-balance font-medium"
            >
              {t('hero.sub' as any)}
            </motion.p>
          </div>


          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5, delay: 0.3 }}
            className="flex flex-col items-center gap-10 w-full"
          >
            <div className="flex flex-wrap items-center justify-center gap-4">
              <a 
                href="https://app.topscoreapp.ai"
                className="bg-slate-900 text-white px-10 py-5 rounded-2xl font-bold text-xl shadow-2xl shadow-slate-200 flex items-center gap-3 transition-all hover:bg-slate-800 hover:-translate-y-1"
              >
                {t('hero.cta' as any)} 
                <ArrowRight className="w-6 h-6" />
              </a>
              <a 
                href="#features"
                className="bg-white border border-slate-200 text-slate-900 px-10 py-5 rounded-2xl font-bold text-xl hover:bg-slate-50 hover:border-slate-300 transition-all"
              >
                {t('hero.explore' as any)}
              </a>
            </div>

            <div className="flex flex-wrap justify-center gap-6 items-center">
              <a href="https://play.google.com/store/apps/details?id=com.topscoreapp.ai" className="transition-transform hover:scale-105 active:scale-95">
                  <img 
                    src="/GetItOnGooglePlay_Badge_Web_color_English.svg" 
                    alt="Get it on Google Play" 
                    className="h-12 w-auto"
                  />
                </a>
                <a href="#" className="transition-transform hover:scale-105 active:scale-95">
                  <img 
                    src="/app-store-badge.svg" 
                    alt="Download on the App Store" 
                    className="h-12 w-auto"
                  />
                </a>
              </div>
            </motion.div>


            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ duration: 1, delay: 0.5 }}
              className="flex items-center gap-8 pt-8 border-t border-slate-200"
            >
              <div className="flex -space-x-3">
                {[1, 2, 3].map((v) => (
                  <div key={v} className="w-10 h-10 rounded-full border-2 border-white bg-slate-200 overflow-hidden">
                    <img src={`https://picsum.photos/seed/user${v}/40/40`} alt="user" className="w-full h-full object-cover" />
                  </div>
                ))}
              </div>
              <p className="text-sm text-slate-500 font-medium">
                <span className="text-slate-900 font-bold">12,000+</span> Kenyan students studying smarter today.
              </p>
            </motion.div>
          </div>

          <div className="lg:col-span-5 grid grid-cols-2 gap-6 mt-16 lg:mt-0">
             <div className="space-y-6">
                <div className="bg-white/60 backdrop-blur-xl p-8 rounded-[2.5rem] shadow-xl shadow-slate-200/40 border border-white flex flex-col gap-4 hover:shadow-2xl transition-all duration-500 hover:-translate-y-1">
                   <div className="w-12 h-12 bg-indigo-50 text-brand-primary rounded-2xl flex items-center justify-center">
                     <Play className="w-5 h-5" />
                   </div>
                   <div>
                    <h3 className="font-bold text-slate-900 tracking-tight">Interactive Quiz</h3>
                    <p className="text-xs text-slate-500 leading-relaxed font-medium">Multiplayer leaderboards and real-time competition for KCSE.</p>
                   </div>
                </div>
                <div className="bg-slate-900 p-8 rounded-[2.5rem] shadow-2xl shadow-slate-900/20 text-white flex flex-col gap-4 transform translate-y-6 overflow-hidden relative group border border-slate-800 hover:shadow-slate-900/30 transition-all duration-500 hover:-translate-y-1">
                   <div className="absolute inset-0 bg-indigo-500/10 group-hover:bg-indigo-500/20 transition-colors" />
                   <div className="relative z-10 space-y-4">
                    <div className="w-12 h-12 bg-white/10 backdrop-blur-md rounded-2xl flex items-center justify-center border border-white/10">
                        <Sparkles className="w-5 h-5 text-indigo-400" />
                    </div>
                    <div>
                      <h3 className="font-bold tracking-tight">Multimodal Live</h3>
                      <p className="text-xs text-slate-400 leading-relaxed font-medium">AI camera vision for step-by-step problem solving.</p>
                    </div>
                   </div>
                </div>
             </div>
             <div className="space-y-6 pt-12">
                <div className="bg-white/60 backdrop-blur-xl p-8 rounded-[2.5rem] shadow-xl shadow-slate-200/40 border border-white flex flex-col gap-4 hover:shadow-2xl transition-all duration-500 hover:-translate-y-1">
                   <div className="w-12 h-12 bg-emerald-50 text-emerald-600 rounded-2xl flex items-center justify-center">
                      <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M7 21h10a2 2 0 002-2V9.414a1 1 0 00-.293-.707l-5.414-5.414A1 1 0 0012.586 3H7a2 2 0 00-2 2v14a2 2 0 002 2z"/></svg>
                   </div>
                   <div>
                    <h3 className="font-bold text-slate-900 tracking-tight">AI PDF Reader</h3>
                    <p className="text-xs text-slate-500 leading-relaxed font-medium">Synced PDF parsing powered by Syncfusion Enterprise.</p>
                   </div>
                </div>
                <div className="bg-white/60 backdrop-blur-xl p-8 rounded-[2.5rem] shadow-xl shadow-slate-200/40 border border-white flex flex-col gap-4 hover:shadow-2xl transition-all duration-500 hover:-translate-y-1">
                   <div className="w-12 h-12 bg-rose-50 text-rose-600 rounded-2xl flex items-center justify-center">
                      <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/></svg>
                   </div>
                   <div>
                    <h3 className="font-bold text-slate-900 tracking-tight">Smart Flashcards</h3>
                    <p className="text-xs text-slate-500 leading-relaxed font-medium">Automatic spaced repetition based on curriculum depth.</p>
                   </div>
                </div>
             </div>
         </div>
      </div>
    </section>
  );
}
