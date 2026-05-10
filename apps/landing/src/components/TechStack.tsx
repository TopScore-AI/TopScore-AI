'use client';
import { motion } from 'framer-motion';
import { Database, ShieldCheck, Zap, Globe } from 'lucide-react';

const techCards = [
  {
    title: "Grounding (RAG)",
    desc: "Our AI is verified against KICD-approved textbooks and national past papers.",
    icon: <Database className="w-6 h-6 text-indigo-400" />,
    detail: "Retrieval Augmented Generation"
  },
  {
    title: "Security & Privacy",
    desc: "Enterprise-grade encryption for student data with local Kenyan hosting.",
    icon: <ShieldCheck className="w-6 h-6 text-emerald-400" />,
    detail: "AES-256 Encryption"
  },

  {
    title: "Syncfusion PDF",
    desc: "Professional document handling for complex diagrams and multi-page guides.",
    icon: <Globe className="w-6 h-6 text-rose-400" />,
    detail: "Enterprise Reader"
  }
];

export default function TechStack() {
  return (
    <section className="py-24 bg-white border-y border-slate-100">
      <motion.div 
        initial={{ opacity: 0, y: 30 }}
        whileInView={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.8, ease: "easeOut" }}
        viewport={{ once: true, margin: "-100px" }}
        className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-10"
      >
        <div className="grid lg:grid-cols-2 gap-20 items-center">
          <div>
            <h2 className="text-sm font-bold text-brand-primary uppercase tracking-[0.25em] mb-4">The Infrastructure</h2>
            <h3 className="text-4xl md:text-5xl lg:text-6xl font-display font-black text-slate-900 tracking-tighter mb-8 leading-[1.05]">
              Enterprise tech for <br className="hidden md:block" /> personal learning.
            </h3>
            <p className="text-slate-600 text-lg leading-relaxed mb-10 font-medium">
              We leverage world-class infrastructure usually reserved for enterprise software to ensure every Kenyan student has a reliable, fast, and grounded AI tutor.
            </p>

            <div className="flex flex-col gap-6">
               <div className="p-6 bg-slate-50 rounded-3xl border border-slate-100 flex gap-5 items-center">
                  <div className="w-12 h-12 bg-white rounded-2xl flex items-center justify-center shadow-sm border border-slate-200 shrink-0">
                    <img src="/logo.png" alt="TopScore AI" className="h-6 opacity-80" />
                  </div>
                  <div>
                    <p className="font-bold text-slate-900">Syncfusion Registered</p>
                    <p className="text-xs text-slate-500 font-medium tracking-wide">Official license for enterprise PDF solutions in Kenya.</p>
                  </div>
               </div>
            </div>
          </div>

          <div className="grid sm:grid-cols-2 gap-6">
            {techCards.map((card, i) => (
              <motion.div
                key={i}
                initial={{ opacity: 0, scale: 0.95 }}
                whileInView={{ opacity: 1, scale: 1 }}
                transition={{ duration: 0.5, delay: i * 0.1 }}
                viewport={{ once: true }}
                className="bg-white p-8 rounded-[2.5rem] border border-slate-100 shadow-sm hover:shadow-xl hover:shadow-indigo-50 transition-all duration-500 group"
              >
                <div className="mb-6 p-4 bg-slate-50 rounded-2xl group-hover:bg-brand-primary/5 transition-colors w-fit">
                  {card.icon}
                </div>
                <h4 className="font-bold text-slate-900 mb-2 tracking-tight">{card.title}</h4>
                <p className="text-sm text-slate-500 leading-relaxed mb-4">{card.desc}</p>
                <div className="pt-4 border-t border-slate-50 text-[10px] font-black text-slate-400 uppercase tracking-widest">
                  {card.detail}
                </div>
              </motion.div>
            ))}
          </div>
        </div>
      </motion.div>
    </section>
  );
}
