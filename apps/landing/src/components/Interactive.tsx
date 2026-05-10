'use client';
import { motion } from 'framer-motion';
import { Trophy, Users, Star, Swords, ArrowRight } from 'lucide-react';

export default function Interactive() {
  return (
    <section className="py-32 overflow-hidden bg-slate-900 rounded-[3.5rem] mx-4 sm:mx-10 relative shadow-2xl">
      <div className="absolute inset-0 bg-[radial-gradient(circle_at_70%_30%,rgba(79,70,229,0.15),transparent_70%)] pointer-events-none" />
      
      <motion.div 
        initial={{ opacity: 0, scale: 0.98, y: 30 }}
        whileInView={{ opacity: 1, scale: 1, y: 0 }}
        transition={{ duration: 1, ease: "easeOut" }}
        viewport={{ once: true, margin: "-100px" }}
        className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-12 relative flex flex-col items-center"
      >
        <div className="text-white text-center mb-16 max-w-3xl">
          <div className="inline-flex items-center gap-2 px-3 py-1 bg-white/5 rounded-full text-[10px] font-bold uppercase tracking-widest mb-8 border border-white/10 mx-auto">
            <Swords className="w-3.5 h-3.5 text-indigo-400" />
            Social Mastery
          </div>
          <h2 className="text-4xl md:text-6xl font-sans font-black mb-8 leading-[1.05] tracking-tight">
            Learn together, <br /> master the curriculum.
          </h2>
          <p className="text-slate-400 text-lg mb-12 leading-relaxed max-w-2xl mx-auto">
            Our competitive study rooms leverage cognitive science to turn revision sessions into elite learning experiences. Challenge peers nationally and track your growth.
          </p>

          <div className="grid md:grid-cols-3 gap-8 text-left">
            {[
              { icon: <Users className="w-5 h-5 text-indigo-400" />, title: "Live Multiplayer", desc: "Real-time synchronized study sessions with up to 100 students." },
              { icon: <Trophy className="w-5 h-5 text-indigo-400" />, title: "National Leaderboards", desc: "Granular ranking data relative to Kenyan national benchmarks." },
              { icon: <Star className="w-5 h-5 text-indigo-400" />, title: "Performance Credits", desc: "Unlock certified achievements and prestige as you scale levels." }
            ].map((item, i) => (
              <div key={i} className="flex flex-col gap-4 items-center text-center p-6 bg-white/5 rounded-3xl border border-white/10">
                <div className="bg-white/5 p-3 rounded-2xl shrink-0 border border-white/10 shadow-inner">
                  {item.icon}
                </div>
                <div>
                  <h4 className="font-sans font-bold text-xl mb-1.5 tracking-tight">{item.title}</h4>
                  <p className="text-slate-500 text-sm leading-relaxed">{item.desc}</p>
                </div>
              </div>
            ))}
          </div>
        </div>

        <div className="relative w-full max-w-3xl">
          <motion.div
            initial={{ opacity: 0, scale: 0.9 }}
            whileInView={{ opacity: 1, scale: 1 }}
            transition={{ duration: 0.8 }}
            viewport={{ once: true }}
            className="bg-white rounded-[2.5rem] p-8 shadow-2xl relative z-10 border border-slate-100 dark:bg-slate-900 dark:border-slate-800"
          >
            <div className="flex items-center justify-between mb-10 border-b border-slate-100 pb-6 dark:border-slate-800">
              <h3 className="font-sans font-bold text-slate-900 text-2xl tracking-tight dark:text-white">KCSE Biology Leaderboard</h3>
              <div className="flex items-center gap-2">
                <div className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
                <span className="text-[10px] font-bold text-slate-400 uppercase tracking-[0.2em]">Live</span>
              </div>
            </div>
            
            <div className="space-y-5">
              {[
                { name: "Faith W.", school: "Alliance Girls", score: "2,450 XP", rank: 1, color: "text-amber-500", bg: "bg-amber-50" },
                { name: "John M.", school: "Starehe Boys", score: "2,100 XP", rank: 2, color: "text-slate-400", bg: "bg-slate-50" },
                { name: "Sarah K.", school: "Kenya High", score: "1,980 XP", rank: 3, color: "text-slate-600", bg: "bg-amber-50/50" }
              ].map((student, i) => (
                <div key={i} className="flex items-center justify-between p-4 rounded-2xl bg-slate-50 border border-slate-100 group hover:border-brand-primary/30 transition-all cursor-default dark:bg-slate-800/50 dark:border-slate-700">
                  <div className="flex items-center gap-5">
                    <span className={`font-sans font-black text-2xl w-8 ${student.color}`}>{student.rank}</span>
                    <div className="w-12 h-12 rounded-full bg-slate-200 border-2 border-white shadow-sm overflow-hidden dark:bg-slate-700 dark:border-slate-600">
                       <img src={`https://picsum.photos/seed/student${i}/48/48`} alt={`Avatar of ${student.name}`} loading="lazy" width={48} height={48} />
                    </div>
                    <div>
                      <p className="font-bold text-slate-900 tracking-tight dark:text-white">{student.name}</p>
                      <p className="text-xs text-slate-500 font-medium dark:text-slate-400">{student.school}</p>
                    </div>
                  </div>
                  <div className="text-right">
                    <p className="font-mono font-bold text-brand-primary text-lg">{student.score}</p>
                    <div className="h-1.5 w-20 bg-slate-200 rounded-full mt-2 overflow-hidden dark:bg-slate-700">
                       <motion.div 
                        initial={{ width: 0 }}
                        whileInView={{ width: "100%" }}
                        transition={{ duration: 1.5, delay: i * 0.3 }}
                        className="h-full bg-brand-primary" 
                       />
                    </div>
                  </div>
                </div>
              ))}
            </div>

            <div className="mt-10 text-center pt-8 border-t border-slate-100 dark:border-slate-800">
               <button className="text-brand-primary font-bold text-sm hover:translate-x-1 transition-transform flex items-center gap-2 mx-auto uppercase tracking-widest" aria-label="Join Battle Royale Study Group">
                Join Battle Royale 
                <ArrowRight className="w-4 h-4" />
               </button>
            </div>
          </motion.div>
          
          <div className="absolute -bottom-12 -left-12 w-48 h-48 bg-white/20 blur-3xl rounded-full pointer-events-none" />
        </div>
      </motion.div>
    </section>
  );
}
