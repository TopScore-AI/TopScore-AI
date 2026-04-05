const fs = require("fs"); 

let l = fs.readFileSync("src/app/layout.tsx", "utf8");
l = l.replace("{ ssr: false }", "{}").replace("{ ssr: false }", "{}").replace("{ ssr: false }", "{}").replace("{ ssr:\nfalse }", "{}").replace("{ ssr:\nfalse }", "{}").replace("{ ssr:\nfalse }", "{}").replace(/\{ ssr:\s*false \}/g, "");
fs.writeFileSync("src/app/layout.tsx", l);

let b = fs.readFileSync("src/components/BackToTop.tsx", "utf8");
b = b.replace(/className=\{\\[\s\S]+?\}/, "className={`fixed bottom-8 right-8 w-12 h-12 rounded-full bg-[image:var(--gradient)] text-white text-xl font-bold border-none cursor-pointer z-[200] shadow-[0_4px_20px_rgba(30,58,138,0.2)] transition-all duration-300 ${visible ? \"translate-y-0 opacity-100 pointer-events-auto\" : \"translate-y-4 opacity-0 pointer-events-none\"} hover:-translate-y-[3px] hover:scale-[1.08] hover:shadow-[0_8px_28px_rgba(30,58,138,0.2)]`}");
fs.writeFileSync("src/components/BackToTop.tsx", b);

let faq = fs.readFileSync("src/components/FAQ.tsx", "utf8");
faq = faq.replace(/const qKey =.+?;/, "const qKey = `faq.${i + 1}.q` as TranslationKey;");
faq = faq.replace(/const aKey =.+?;/, "const aKey = `faq.${i + 1}.a` as TranslationKey;");
faq = faq.replace(/delay=\{\\\\s\\\}/, "delay={0.1}");
fs.writeFileSync("src/components/FAQ.tsx", faq);

let f = fs.readFileSync("src/components/Features.tsx", "utf8");
f = f.replace(/const titleKey =.+?;/, "const titleKey = `features.${i + 1}.title` as TranslationKey;");
f = f.replace(/const descKey =.+?;/, "const descKey = `features.${i + 1}.desc` as TranslationKey;");
f = f.replace(/const tagsKey =.+?;/, "const tagsKey = `features.${i + 1}.tags` as TranslationKey;");
fs.writeFileSync("src/components/Features.tsx", f);

let h = fs.readFileSync("src/components/Hero.tsx", "utf8");
h = h.replace(/className=\{[\s\w\-\[\]\(\)\:]+\}{a}<\/span>/, "className={`w-10 h-10 -ml-4 flex items-center justify-center bg-[var(--bg-card)] text-[22px] rounded-full border-2 border-[var(--bg)] leading-none z-[${5 - i}]`}>{a}</span>");
fs.writeFileSync("src/components/Hero.tsx", h);

