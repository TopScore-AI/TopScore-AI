'use client';
import Image from 'next/image';
import { useLocale } from '@/i18n';
import AnimatedSection from './AnimatedSection';
import styles from './CtaBanner.module.css';

export default function CtaBanner() {
    const { locale, t } = useLocale();

    const playBadgeSrc = '/GetItOnGooglePlay_Badge_Web_color_English.svg';
    const playBadgeAlt = 'Get it on Google Play';

    return (
        <section id="download" className={styles.wrapper}>
            <div className={styles.inner}>
                <AnimatedSection animation="fadeUp">
                    <div className={styles.card}>
                        <div className={styles.cardGlow} />
                        <div className={styles.label}>{t('cta.label')}</div>
                        <h2 className={styles.title}>
                            {t('cta.title')} <br />
                            <span className={styles.gradText}>{t('cta.titleGrad')}</span>
                        </h2>
                        <p className={styles.sub}>{t('cta.sub')}</p>

                        <div className={styles.buttons}>
                            <a href="/download" className={styles.storeBtn} aria-label={playBadgeAlt}>
                                <Image src={playBadgeSrc} alt={playBadgeAlt} width={200} height={59} className={styles.badge} />
                            </a>
                            <a href="/download" className={styles.storeBtn} aria-label="Download on the App Store">
                                <Image src="/app-store-badge.svg" alt="Download on the App Store" width={200} height={59} className={styles.badge} />
                            </a>
                        </div>
                    </div>
                </AnimatedSection>
            </div>
        </section>
    );
}
