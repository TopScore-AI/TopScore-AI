'use client';
import { useLocale } from '@/i18n';
import AnimatedSection from './AnimatedSection';
import { Button } from '@/components/ui/button';
import { Check } from 'lucide-react';
import styles from './Pricing.module.css';

const pricingPlans = [
    {
        name: 'Free',
        price: 'KSh 0',
        period: '/month',
        description: 'Perfect for getting started and exploring the platform.',
        features: [
            'Access to standard AI Tutor',
            'Up to 5 photo scans per day',
            'Basic progress tracking',
            'Community support',
        ],
        ctaText: 'Get Started for Free',
        ctaLink: 'https://app.topscoreapp.ai/register',
        popular: false,
    },
    {
        name: 'Premium',
        price: 'KSh 499',
        period: '/month',
        description: 'Unlock unlimited potential and ace your exams faster.',
        features: [
            'Unlimited AI Tutor access',
            'Unlimited photo scans (Math & Science)',
            'Unlimited past papers downloads',
            'Detailed analytics & insights',
            'Priority 24/7 support',
            'Offline mode capabilities',
        ],
        ctaText: 'Upgrade to Premium',
        ctaLink: 'https://app.topscoreapp.ai/upgrade',
        popular: true,
    },
];

export default function Pricing() {
    const { t } = useLocale();

    return (
        <section className={styles.pricing} id="pricing">
            <div className={styles.container}>
                <AnimatedSection animation="fadeUp">
                    <div className={styles.header}>
                        <h2 className={styles.title}>Simple, Transparent Pricing</h2>
                        <p className={styles.subtitle}>Start for free, upgrade when you need more power.</p>
                    </div>
                </AnimatedSection>

                <div className={styles.grid}>
                    {pricingPlans.map((plan, index) => (
                        <AnimatedSection animation="fadeUp" delay={`${index * 0.2}s`} key={plan.name}>
                            <div className={`${styles.card} ${plan.popular ? styles.popular : ''}`}>
                                {plan.popular && <div className={styles.popularBadge}>Most Popular</div>}
                                <div className={styles.cardHeader}>
                                    <h3 className={styles.planName}>{plan.name}</h3>
                                    <div className={styles.priceContainer}>
                                        <span className={styles.price}>{plan.price}</span>
                                        <span className={styles.period}>{plan.period}</span>
                                    </div>
                                    <p className={styles.description}>{plan.description}</p>
                                </div>
                                <div className={styles.features}>
                                    {plan.features.map((feature, i) => (
                                        <div key={i} className={styles.featureItem}>
                                            <Check className={styles.checkIcon} size={20} />
                                            <span>{feature}</span>
                                        </div>
                                    ))}
                                </div>
                                <div className={styles.action}>
                                    <Button
                                        asChild
                                        size="lg"
                                        className={plan.popular ? styles.btnPrimary : styles.btnSecondary}
                                        variant={plan.popular ? 'default' : 'outline'}
                                    >
                                        <a href={plan.ctaLink}>{plan.ctaText}</a>
                                    </Button>
                                </div>
                            </div>
                        </AnimatedSection>
                    ))}
                </div>
            </div>
        </section>
    );
}