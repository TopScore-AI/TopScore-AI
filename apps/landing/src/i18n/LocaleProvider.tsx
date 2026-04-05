'use client';

import type { ReactNode } from 'react';
import en, { type TranslationKey } from './en';

/**
 * TopScore AI Landing - English Only Refactor
 * We maintain the 't' function pattern for content management,
 * but remove all multi-language overhead to prioritize SEO and simplicity.
 */

export type Locale = 'en';

export function LocaleProvider({ children }: { children: ReactNode }) {
    // We keep the provider name to maintain component compatibility,
    // but it no longer manages state or context.
    return <>{children}</>;
}

export function useLocale() {
    // useLocale now returns a static English implementation.
    // This prevents any 'context not found' errors in existing components.
    
    const t = (key: TranslationKey, vars?: Record<string, string>) => {
        let value = (en as any)[key] ?? key;
        if (vars) {
            for (const [k, v] of Object.entries(vars)) {
                // Handle simple variable replacement
                value = value.replace(`{${k}}`, v);
            }
        }
        return value;
    };

    return { 
        locale: 'en' as const, 
        t, 
        setLocale: () => {
            console.warn('TopScore AI is now English-only. setLocale is disabled.');
        } 
    };
}
