'use client';
import { useLocale } from '@/i18n';
import AnimatedSection from './AnimatedSection';
import { Button } from '@/components/ui/button';
import Image from 'next/image';
import styles from './Hero.module.css';

export default function Hero() {
    const { t } = useLocale();

    return (
        <section className={styles.hero} id="home">
            <div className={styles.bg} aria-hidden />
            
            <div className={styles.container}>
                <div className={styles.grid}>
                    <div className={styles.textSide}>
                        <AnimatedSection animation="fadeUp" delay="0s">
                            <div className={styles.badge}>
                                <span className={styles.livePulse} />
                                {t('hero.badge')}
                            </div>
                        </AnimatedSection>

                        <AnimatedSection animation="fadeUp" delay="0.1s">
                            <h1 className={`${styles.h1} font-serif`}>
                                {t('hero.h1a')}<span className={styles.gradText}>{t('hero.h1Grad')}</span><br />
                                {t('hero.h1b')}
                            </h1>
                        </AnimatedSection>

                        <AnimatedSection animation="fadeUp" delay="0.2s">
                            <p className={`${styles.sub} prose-editorial`}>
                                {t('hero.sub')}
                            </p>
                        </AnimatedSection>

                        <AnimatedSection animation="fadeUp" delay="0.3s">
                            <div className={styles.actions}>
                                <Button asChild size="lg" className={styles.btnPrimary}>
                                    <a href="https://app.topscoreapp.ai">
                                        {t('hero.cta')}
                                    </a>
                                </Button>
                                <Button asChild variant="outline" size="lg" className={styles.btnSecondary}>
                                    <a href="/features">
                                        {t('hero.explore')}
                                    </a>
                                </Button>
                            </div>
                        </AnimatedSection>

                        <AnimatedSection animation="fadeUp" delay="0.35s">
                            <div className={styles.socialProof}>
                                <div className={styles.avatars} aria-hidden>
                                    {['👩🏾‍🎓','👨🏾‍🎓','👩🏾','👦🏾','🧑🏾‍💻'].map((a, i) => (
                                        <span key={i} className={styles.avatar}>{a}</span>
                                    ))}
                                </div>
                                <p>Trusted by All Learners in Kenya</p>
                            </div>
                        </AnimatedSection>
                    </div>

                    <div className={styles.visualSide}>
                        <AnimatedSection animation="fadeUp" delay="0.4s">
                            <div className={styles.mockupContainer}>
                                <div className={styles.mockupGlow} />
                                <Image 
                                    src="/topscore_app_mockup.png" 
                                    alt="TopScore AI Mobile App - Kenya's #1 AI Tutor for KCSE, CBC & IGCSE" 
                                    width={600} 
                                    height={800} 
                                    className={styles.mockupImg}
                                    priority
                                />
                            </div>
                        </AnimatedSection>
                    </div>
                </div>
            </div>
        </section>
    );
}
