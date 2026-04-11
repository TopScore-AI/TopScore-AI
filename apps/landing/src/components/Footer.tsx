'use client';
import Link from 'next/link';
import Image from 'next/image';
import { useLocale } from '@/i18n';
import { Facebook, Twitter, Instagram, Linkedin, ExternalLink, ShieldCheck, Heart, Apple, Play } from "lucide-react";
import styles from './Footer.module.css';



export default function Footer() {
    const year = 2026; // Hardcoded for stability or could use suppressHydrationWarning
    const { t } = useLocale();

    return (
        <footer className={styles.footer}>
            <div className={styles.container}>
                {/* Newsletter Section */}
                <div className={styles.newsletterSection}>
                    <div className={styles.newsletterText}>
                        <h3>Stay ahead in your studies</h3>
                        <p>Get study tips and AI updates delivered to your inbox.</p>
                    </div>
                    <form className={styles.newsletterForm} onSubmit={(e) => e.preventDefault()}>
                        <input 
                            type="email" 
                            placeholder="Enter your email" 
                            className={styles.newsletterInput}
                            required 
                        />
                        <button type="submit" className={styles.newsletterSubmit}>
                            Subscribe
                        </button>
                    </form>
                </div>

                <div className={styles.grid}>
                    <div className={styles.brand}>
                        <div className={styles.logo}>
                            <Image src="/logo.png" alt="TopScore AI" width={40} height={40} />
                            <span className={styles.brandName}>TopScore AI</span>
                        </div>
                        <p className={styles.tagline}>
                            The #1 AI Study Companion in Kenya. empowering students from CBC Early Years to KCSE Form 4 and IGCSE.
                        </p>
                        
                        <div className={styles.appLinks}>
                            <Link href="/download" className={styles.appBadge}>
                                <Image 
                                    src="/app-store-badge.svg" 
                                    alt="Download on the App Store" 
                                    width={140} 
                                    height={42}
                                />
                            </Link>
                            <Link href="/download" className={styles.appBadge}>
                                <Image 
                                    src="/GetItOnGooglePlay_Badge_Web_color_English.svg" 
                                    alt="Get it on Google Play" 
                                    width={158} 
                                    height={42}
                                />
                            </Link>
                        </div>

                        <div className={styles.socials}>
                            <a href="https://facebook.com/TopScoreAI" className={styles.socialIcon} aria-label="Facebook"><Facebook size={20} /></a>
                            <a href="https://twitter.com/TopScoreAI" className={styles.socialIcon} aria-label="Twitter"><Twitter size={20} /></a>
                            <a href="https://instagram.com/TopScoreAI" className={styles.socialIcon} aria-label="Instagram"><Instagram size={20} /></a>
                            <a href="https://linkedin.com/company/topscore-ai" className={styles.socialIcon} aria-label="LinkedIn"><Linkedin size={20} /></a>
                        </div>
                    </div>


                </div>

                <div className={styles.trustSection}>
                    <div className={styles.trustBadges}>
                        <div className={styles.badge}>
                            <ShieldCheck size={18} className="text-green-500" />
                            <span>KICD Compliant Content</span>
                        </div>
                        <div className={styles.badge}>
                            <Heart size={18} className="text-red-500" />
                            <span>Safe for Learners</span>
                        </div>
                    </div>
                    
                    <div className={styles.kenyaBadge}>
                        <span>Built with ❤️ in Kenya</span>
                    </div>
                </div>

                <div className={styles.bottom}>
                    <p className={styles.copy}>
                        © {year} TopScore AI. All rights reserved.
                    </p>
                    <div className={styles.legal}>
                        <Link href="/privacy">Privacy Policy</Link>
                        <Link href="/terms">Terms</Link>
                        <Link href="/sitemap.xml">Sitemap</Link>
                    </div>
                </div>
            </div>
        </footer>
    );
}
