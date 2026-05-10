'use client';
import { motion } from 'framer-motion';
import { Check, Sparkles } from 'lucide-react';

const tiers = [
  {
    name: "Basic",
    price: "Free",
    desc: "Perfect for casual study sessions.",
    features: ["3 AI Scans per day", "Standard KCSE Notes", "Community Quizzes", "Web Access"],
    cta: "Start Free",
    featured: false
  },
  {
    name: "Weekly Scholar",
    price: "KES 300",
    period: "/wk",
    desc: "Quick boost before exams.",
    features: ["Unlimited AI Scans", "Gemini Live API Voice Tutor", "Multi-Curriculum Switcher", "Full Practice Library", "Priority Support"],
    cta: "Get Weekly",
    featured: false
  },
  {
    name: "Monthly Scholar",
    price: "KES 1000",
    period: "/mo",
    desc: "Best value for consistent performance.",
    features: ["Everything in Weekly", "Personal Progress Analytics", "Custom Quiz Generator", "Download Study Guides", "National Rank Tracking"],
    cta: "Go Monthly",
    featured: true
  }
];

export default function Pricing() {
  return (
    <section id="pricing" className="py-24 bg-white relative">
      <motion.div 
        initial={{ opacity: 0, y: 30 }}
        whileInView={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.8, ease: "easeOut" }}
        viewport={{ once: true, margin: "-100px" }}
        className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-10"
      >
        <div className="text-center mb-16">
          <h2 className="text-sm font-bold text-brand-primary uppercase tracking-[0.25em] mb-4">Investment</h2>
          <h3 className="text-4xl md:text-5xl lg:text-6xl font-display font-black text-slate-900 tracking-tighter leading-[1.05]">
            Flexible plans for <br className="hidden md:block" /> every scholar.
          </h3>
        </div>

        <div className="grid lg:grid-cols-3 gap-8 items-stretch">
          {tiers.map((tier, i) => (
            <motion.div
              key={i}
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.5, delay: i * 0.1 }}
              viewport={{ once: true }}
              className={`relative flex flex-col p-8 rounded-[2.5rem] border ${tier.featured ? 'bg-slate-900 text-white border-slate-800 shadow-2xl' : 'bg-slate-50 text-slate-900 border-slate-100 hover:bg-white hover:shadow-xl' } transition-all duration-500`}
            >
              {tier.featured && (
                <div className="absolute -top-4 left-1/2 -translate-x-1/2 bg-brand-primary text-white text-[10px] font-black uppercase tracking-widest px-4 py-1.5 rounded-full flex items-center gap-1.5 shadow-lg">
                  <Sparkles className="w-3 h-3" />
                  Most Popular
                </div>
              )}
              
              <div className="mb-8">
                <h4 className={`text-xl font-display font-bold mb-2 ${tier.featured ? 'text-brand-primary' : 'text-slate-900'}`}>{tier.name}</h4>
                <div className="flex items-baseline gap-1">
                  <span className="text-4xl font-display font-black tracking-tight">{tier.price}</span>
                  {tier.period && <span className={`${tier.featured ? 'text-slate-500' : 'text-slate-400'} text-sm font-medium`}>{tier.period}</span>}
                </div>
                <p className={`mt-2 text-sm font-medium ${tier.featured ? 'text-slate-400' : 'text-slate-500'}`}>{tier.desc}</p>
              </div>


              <div className="flex-grow space-y-4 mb-10">
                {tier.features.map((f, j) => (
                  <div key={j} className="flex items-start gap-3">
                    <div className={`mt-1 shrink-0 w-4 h-4 rounded-full flex items-center justify-center ${tier.featured ? 'bg-brand-primary/20 text-brand-primary' : 'bg-brand-primary/10 text-brand-primary'}`}>
                      <Check className="w-2.5 h-2.5" />
                    </div>
                    <span className={`text-sm font-medium ${tier.featured ? 'text-slate-300' : 'text-slate-600'}`}>{f}</span>
                  </div>
                ))}
              </div>

              <a 
                href="https://app.topscoreapp.ai"
                className={`w-full py-4 rounded-2xl font-bold text-center transition-all ${tier.featured ? 'bg-brand-primary text-white hover:bg-brand-primary/90 shadow-lg shadow-indigo-900/20' : 'bg-white border border-slate-200 text-slate-900 hover:bg-slate-50'}`}
              >
                {tier.cta}
              </a>
            </motion.div>
          ))}
        </div>
      </motion.div>
    </section>
  );
}
