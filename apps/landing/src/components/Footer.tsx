'use client';
import Link from 'next/link';
import Image from 'next/image';
import { useLocale } from '@/i18n';
import styles from './Footer.module.css';

const productLinks = [
    { href: '/features', key: 'nav.features' as const },
    { href: '/how-it-works', key: 'nav.howItWorks' as const },
    { href: '/tools', key: 'nav.tools' as const },
    { href: '/pricing', key: 'nav.pricing' as const },
];

const resourceLinks = [
    { href: '/download', label: 'Download App' },
    { href: 'https://app.topscoreapp.ai', label: 'Web App', external: true },
    { href: '/sitemap.xml', label: 'Sitemap' },
];

const legalLinks = [
    { href: '/privacy', key: 'footer.privacy' as const },
    { href: '/terms', key: 'footer.terms' as const },
];

export default function Footer() {
    const year = new Date().getFullYear();
    const { t } = useLocale();

    return (
        <footer className={styles.footer}>
            <div className={styles.grid}>
                {/* Brand column */}
                <div className={styles.brand}>
                    <div className={styles.logo}>
                        <Image src="/logo.png" alt="TopScore AI" width={32} height={32} />
                        <span>TopScore AI</span>
                    </div>
                    <p className={styles.tagline}>{t('footer.tagline')}</p>
                    <div className={styles.storeBadges}>
                        <a
                            href="https://play.google.com/store/apps/details?id=com.topscoreapp.ai"
                            target="_blank"
                            rel="noopener noreferrer"
                            aria-label="Get it on Google Play"
                        >
                            <Image src="/GetItOnGooglePlay_Badge_Web_color_English.svg" alt="Google Play" width={120} height={36} />
                        </a>
                        <a
                            href="https://apps.apple.com/app/id6400000000"
                            target="_blank"
                            rel="noopener noreferrer"
                            aria-label="Download on App Store"
                        >
                            <Image src="/app-store-badge.svg" alt="App Store" width={120} height={36} />
                        </a>
                    </div>
                </div>

                {/* Product links */}
                <div className={styles.linkCol}>
                    <h4 className={styles.colTitle}>Product</h4>
                    <ul>
                        {productLinks.map(({ href, key }) => (
                            <li key={href}>
                                <Link href={href}>{t(key)}</Link>
                            </li>
                        ))}
                    </ul>
                </div>

                {/* Resources */}
                <div className={styles.linkCol}>
                    <h4 className={styles.colTitle}>Resources</h4>
                    <ul>
                        {resourceLinks.map(({ href, label, external }) => (
                            <li key={href}>
                                {external ? (
                                    <a href={href} target="_blank" rel="noopener noreferrer">{label}</a>
                                ) : (
                                    <Link href={href}>{label}</Link>
                                )}
                            </li>
                        ))}
                    </ul>
                </div>

                {/* Legal */}
                <div className={styles.linkCol}>
                    <h4 className={styles.colTitle}>Legal</h4>
                    <ul>
                        {legalLinks.map(({ href, key }) => (
                            <li key={href}>
                                <Link href={href}>{t(key)}</Link>
                            </li>
                        ))}
                    </ul>
                </div>
            </div>

            <div className={styles.bottom}>
                <p>{t('footer.copy', { year: String(year) })}</p>
            </div>
        </footer>
    );
}
