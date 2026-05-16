'use client';
import { motion } from 'framer-motion';
import { GraduationCap, BookOpen, Clock } from 'lucide-react';

const curricula = [
  {
    title: "CBE",
    subtitle: "Competency Based Education",
    desc: "Personalized learning paths designed to build real-world skills and competencies for the modern Kenyan workforce.",
    icon: <GraduationCap className="w-8 h-8" />,
    color: "bg-blue-500"
  },
  {
    title: "IGCSE",
    subtitle: "International Standard",
    desc: "Rigorous preparation for IGCSE exams with international standard resources and AI-driven deep understanding.",
    icon: <BookOpen className="w-8 h-8" />,
    color: "bg-emerald-500"
  },
  {
    title: "8-4-4",
    subtitle: "Transition Phase",
    desc: "Full support for students completing the 8-4-4 cycle, with comprehensive past papers and study guides.",
    icon: <Clock className="w-8 h-8" />,
    color: "bg-amber-500"
  }
];

export default function Curriculum() {
  return (
    <section id="curriculum" className="py-24 bg-white border-t border-slate-50">
      <motion.div 
        initial={{ opacity: 0, y: 30 }}
        whileInView={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.8, ease: "easeOut" }}
        viewport={{ once: true, margin: "-100px" }}
        className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-10"
      >
        <div className="text-center mb-20">
          <h2 className="text-sm font-bold text-brand-primary uppercase tracking-[0.25em] mb-6">Kenyan Standards</h2>
          <h3 className="text-4xl md:text-5xl lg:text-6xl font-display font-black text-slate-900 mb-6 tracking-tighter leading-[1.05]">
            A Curriculum for <br className="hidden md:block" /> Every Ambition.
          </h3>
          <p className="text-slate-600 max-w-2xl mx-auto text-xl leading-relaxed font-medium">Whether you're navigating the new CBE system, excelling in IGCSE, or concluding the 8-4-4 cycle, our engine adapts to your specific academic requirements.</p>
        </div>

        <div className="grid md:grid-cols-3 gap-8">
          {curricula.map((item, i) => (
            <motion.div
              key={i}
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.5, delay: i * 0.1 }}
              viewport={{ once: true }}
              className="bg-slate-50/50 backdrop-blur-sm p-10 rounded-[2.5rem] border border-slate-100 hover:bg-white hover:shadow-2xl hover:shadow-indigo-100/50 transition-all duration-500 group relative overflow-hidden"
            >
              <div className="absolute top-0 right-0 p-4 opacity-5 group-hover:opacity-10 transition-opacity">
                {item.icon}
              </div>
              <div className={`${item.color} w-16 h-16 rounded-2xl flex items-center justify-center text-white mb-10 shadow-xl shadow-current/20 group-hover:scale-110 group-hover:rotate-3 transition-transform duration-500`}>
                {item.icon}
              </div>
              <div className="space-y-4">
                <span className="text-[10px] font-black text-slate-500 tracking-[0.2em] uppercase block">{item.subtitle}</span>
                <h4 className="text-3xl font-display font-black text-slate-900 tracking-tight">{item.title}</h4>
                <p className="text-slate-600 leading-relaxed text-base font-medium">{item.desc}</p>
              </div>
            </motion.div>
          ))}
        </div>

      </motion.div>
    </section>
  );
}
