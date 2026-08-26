// @ts-nocheck
/* =========================================================================
 * REFERENCE ONLY FILE - NOT PART OF THE ACTIVE FLUTTER BUILD
 * This Next.js layout was provided as architectural & route reference.
 * ========================================================================= */

import Link from "next/link";
import { Button } from "@/components/ui/button";
import { createClient } from "@/utils/supabase/server";
import { logout } from "@/app/actions";

export default async function PublicLayout({ children }: { children: React.ReactNode }) {
    // Check if there is an active user session
    const supabase = await createClient();
    const { data: { user } } = await supabase.auth.getUser();

    return (
        <div className="min-h-screen bg-slate-50 flex flex-col">
            <header className="border-b bg-white px-6 py-4 flex items-center justify-between sticky top-0 z-10">
                <div className="flex items-center space-x-6">
                    <Link href="/" className="font-bold text-xl text-emerald-600">
                        SmashCourt
                    </Link>
                    <nav className="hidden md:flex space-x-4">
                        <Link href="/book" className="text-sm font-medium text-slate-600 hover:text-slate-900 transition-colors">
                            Book a Court
                        </Link>
                        <Link href="/pricing" className="text-sm font-medium text-slate-600 hover:text-slate-900 transition-colors">
                            Pricing
                        </Link>
                    </nav>
                </div>

                {/* Dynamic Auth Buttons */}
                <div className="flex items-center space-x-3">
                    {user ? (
                        <>
                            <Link href="/dashboard">
                                <Button variant="outline" className="border-emerald-200 text-emerald-700 hover:bg-emerald-50">
                                    Dashboard
                                </Button>
                            </Link>
                            <form action={logout}>
                                <Button variant="ghost" type="submit" className="text-slate-600 hover:text-red-600 hover:bg-red-50">
                                    Sign Out
                                </Button>
                            </form>
                        </>
                    ) : (
                        <>
                            <Link href="/login">
                                <Button variant="outline">Log in</Button>
                            </Link>
                            <Link href="/signup">
                                <Button className="bg-emerald-600 hover:bg-emerald-700 text-white">Sign up</Button>
                            </Link>
                        </>
                    )}
                </div>
            </header>
            <main className="flex-1 flex flex-col">{children}</main>
        </div>
    );
}