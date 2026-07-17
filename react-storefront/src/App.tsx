import React, { useState } from 'react';
import { Search, ShoppingCart, User, Star, ArrowRight, ArrowLeft, Plus } from 'lucide-react';
import { SignInPage } from '@/components/ui/sign-in';
import type { Testimonial } from '@/components/ui/sign-in';
import { RegisterPage } from '@/components/ui/register';

// Standard Unsplash images for products and avatars
const productsData = [
  {
    id: 'p1',
    name: 'Classmate A4 Notebook (Pack of 6)',
    price: 360,
    rating: 4.8,
    category: 'Notebooks',
    image: 'https://images.unsplash.com/photo-1531346878377-a5be20888e57?auto=format&fit=crop&w=400&q=80'
  },
  {
    id: 'p2',
    name: 'Parker Vector Fountain Pen',
    price: 450,
    rating: 4.5,
    category: 'Stationary',
    image: 'https://images.unsplash.com/photo-1583485088034-697b5bc54ccd?auto=format&fit=crop&w=400&q=80'
  },
  {
    id: 'p3',
    name: 'Handcrafted Leather Bookmark',
    price: 180,
    rating: 4.9,
    category: 'Bookmarks',
    image: 'https://images.unsplash.com/photo-1512820790803-83ca734da794?auto=format&fit=crop&w=400&q=80'
  },
  {
    id: 'p4',
    name: 'The Alchemist - Hardcover Special Edition',
    price: 599,
    rating: 4.7,
    category: 'Textbooks',
    image: 'https://images.unsplash.com/photo-1544947950-fa07a98d237f?auto=format&fit=crop&w=400&q=80'
  },
  {
    id: 'p5',
    name: 'Premium Drawing Pencils (12-Grade Pack)',
    price: 240,
    rating: 4.3,
    category: 'Writing Materials',
    image: 'https://images.unsplash.com/photo-1513542789411-b6a5d4f31634?auto=format&fit=crop&w=400&q=80'
  },
  {
    id: 'p6',
    name: 'Faber-Castell Connector Paint Set',
    price: 320,
    rating: 4.6,
    category: 'Stationary',
    image: 'https://images.unsplash.com/photo-1513364776144-60967b0f800f?auto=format&fit=crop&w=400&q=80'
  }
];

const testimonialsData: Testimonial[] = [
  {
    avatarSrc: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=100&q=80',
    name: 'Priya Sharma',
    handle: '@priya_books',
    text: 'Rama Store has been my go-to counter for university registers since 1998. Extremely quick shipping!'
  },
  {
    avatarSrc: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=100&q=80',
    name: 'Rahul Patel',
    handle: '@patel_rahul',
    text: 'Love the premium bookmark catalog. High quality materials, local values, outstanding service.'
  },
  {
    avatarSrc: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?auto=format&fit=crop&w=100&q=80',
    name: 'Anjali Gupta',
    handle: '@anjali_draws',
    text: 'Amazing collection of writing tools. Highly recommended for neighborhood counters!'
  }
];

interface CartItem {
  product_id: string;
  name: string;
  price: number;
  image: string;
  quantity: number;
}

export default function App() {
  const [view, setView] = useState<'home' | 'login' | 'register'>('home');
  const [user, setUser] = useState<{ name: string; email: string } | null>(null);
  const [cart, setCart] = useState<CartItem[]>([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedCategory, setSelectedCategory] = useState<string | null>(null);
  const [cartBounce, setCartBounce] = useState(false);
  const [toast, setToast] = useState<{ msg: string; type: 'success' | 'error' } | null>(null);

  const showToastMsg = (msg: string, type: 'success' | 'error' = 'success') => {
    setToast({ msg, type });
    setTimeout(() => setToast(null), 3000);
  };

  const handleAddToCart = (product: typeof productsData[0]) => {
    setCart((prev) => {
      const existing = prev.find(item => item.product_id === product.id);
      if (existing) {
        return prev.map(item => item.product_id === product.id ? { ...item, quantity: item.quantity + 1 } : item);
      }
      return [...prev, { product_id: product.id, name: product.name, price: product.price, image: product.image, quantity: 1 }];
    });
    
    // Trigger cart badge bounce
    setCartBounce(true);
    setTimeout(() => setCartBounce(false), 300);
    showToastMsg(`Added "${product.name}" to cart.`);
  };

  const totalCartCount = cart.reduce((acc, item) => acc + item.quantity, 0);

  const handleSignIn = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const data = new FormData(e.currentTarget);
    const email = data.get('email') as string;
    if (email) {
      setUser({ name: email.split('@')[0], email });
      setView('home');
      showToastMsg(`Welcome back, ${email.split('@')[0]}!`);
    }
  };

  const handleRegister = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const data = new FormData(e.currentTarget);
    const name = data.get('name') as string;
    const email = data.get('email') as string;
    if (name && email) {
      setUser({ name, email });
      setView('home');
      showToastMsg(`Account created for ${name}!`);
    }
  };

  const handleLogout = () => {
    setUser(null);
    showToastMsg("Signed out successfully.");
  };

  const filteredProducts = productsData.filter(p => {
    const matchesSearch = p.name.toLowerCase().includes(searchQuery.toLowerCase());
    const matchesCategory = selectedCategory ? p.category === selectedCategory : true;
    return matchesSearch && matchesCategory;
  });

  return (
    <div className="min-h-screen bg-neutral-50 text-zinc-900 font-sans flex flex-col">
      {/* Toast Notifications */}
      {toast && (
        <div className={`fixed bottom-4 right-4 z-50 px-4 py-3 rounded-xl shadow-lg flex items-center gap-2 text-sm font-medium text-white transition-all transform translate-y-0 ${toast.type === 'success' ? 'bg-emerald-600' : 'bg-rose-600'}`}>
          <span>{toast.type === 'success' ? '✅' : '❌'}</span>
          <span>{toast.msg}</span>
        </div>
      )}

      {view === 'home' && (
        <>
          {/* Sticky Header */}
          <header className="sticky top-0 z-40 bg-zinc-900 text-white shadow-md">
            <div className="max-w-7xl mx-auto px-4 h-16 flex items-center justify-between gap-4">
              {/* Logo */}
              <div className="flex items-center gap-2 cursor-pointer" onClick={() => { setSelectedCategory(null); setSearchQuery(''); }}>
                <span className="text-xl font-bold tracking-tight text-amber-500">Rama <span className="text-white">Store</span></span>
              </div>

              {/* Search Bar */}
              <div className="flex-1 max-w-2xl relative">
                <input
                  type="text"
                  placeholder="Search textbook copies, journals, calligraphy pens..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="w-full bg-zinc-800 text-white text-sm pl-4 pr-10 py-2 rounded-xl focus:outline-none focus:ring-2 focus:ring-amber-500 transition-all border border-zinc-700"
                />
                <Search className="w-5 h-5 text-zinc-400 absolute right-3 top-2.5" />
              </div>

              {/* Header Action Buttons */}
              <div className="flex items-center gap-4">
                {user ? (
                  <div className="flex items-center gap-3">
                    <span className="text-sm font-medium text-amber-500 hidden sm:inline">Hi, {user.name}</span>
                    <button onClick={handleLogout} className="text-xs text-zinc-400 hover:text-white border border-zinc-700 rounded-lg px-2.5 py-1.5 transition-colors">Logout</button>
                  </div>
                ) : (
                  <button onClick={() => setView('login')} className="flex items-center gap-1 text-sm font-medium hover:text-amber-500 transition-colors">
                    <User className="w-5 h-5" />
                    <span>Sign In</span>
                  </button>
                )}

                {/* Cart Badge Trigger */}
                <button className="relative p-2 hover:text-amber-500 transition-colors">
                  <ShoppingCart className="w-6 h-6" />
                  {totalCartCount > 0 && (
                    <span className={`absolute -top-1 -right-1 bg-amber-500 text-zinc-900 font-bold text-xs rounded-full h-5 w-5 flex items-center justify-center transition-transform ${cartBounce ? 'scale-130' : 'scale-100'}`}>
                      {totalCartCount}
                    </span>
                  )}
                </button>
              </div>
            </div>

            {/* Category Navigation Strip */}
            <div className="bg-zinc-800 border-t border-zinc-700 text-zinc-200">
              <div className="max-w-7xl mx-auto px-4 h-10 flex items-center gap-6 overflow-x-auto text-xs font-semibold uppercase tracking-wider">
                <button onClick={() => setSelectedCategory(null)} className={`hover:text-amber-500 transition-colors whitespace-nowrap ${!selectedCategory ? 'text-amber-500' : ''}`}>All Departments</button>
                {['Textbooks', 'Notebooks', 'Stationary', 'Bookmarks', 'Writing Materials'].map((cat) => (
                  <button
                    key={cat}
                    onClick={() => setSelectedCategory(cat)}
                    className={`hover:text-amber-500 transition-colors whitespace-nowrap ${selectedCategory === cat ? 'text-amber-500' : ''}`}
                  >
                    {cat}
                  </button>
                ))}
              </div>
            </div>
          </header>

          {/* Main Dashboard Layout */}
          <main className="flex-1 max-w-7xl mx-auto px-4 py-8 w-full">
            {/* Hero Carousel Banner */}
            <div className="bg-zinc-900 text-white rounded-3xl p-8 mb-8 flex flex-col md:flex-row items-center justify-between gap-6 relative overflow-hidden shadow-lg border border-zinc-800">
              <div className="relative z-10 max-w-lg">
                <span className="text-amber-500 text-xs font-bold uppercase tracking-widest">Neighborhood Counter since 1994</span>
                <h1 className="text-3xl md:text-5xl font-extrabold tracking-tight mt-2 mb-4 leading-tight">Authentic Writing & Reading Supplies</h1>
                <p className="text-zinc-300 text-sm mb-6 leading-relaxed">Shop fresh registers, fountain pens, and textbooks with flat 10% counter checkout rewards points.</p>
                <button onClick={() => setSelectedCategory('Textbooks')} className="bg-amber-500 text-zinc-900 px-6 py-3 rounded-2xl font-bold hover:bg-amber-400 transition-all transform hover:-translate-y-0.5 inline-flex items-center gap-2">
                  <span>Browse Textbooks</span>
                  <ArrowRight className="w-5 h-5" />
                </button>
              </div>
              <div className="text-8xl md:text-[10rem] opacity-25 select-none relative z-0 md:mr-8">📚</div>
            </div>

            {/* Reorder / Usual Basket shortcut banner */}
            <div className="bg-amber-50 border border-amber-200 rounded-3xl p-6 mb-8 shadow-sm">
              <h2 className="text-lg font-bold text-zinc-800 mb-4 tracking-tight flex items-center gap-2">
                <span>🔄</span> Reorder Your Usual Basket
              </h2>
              <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-4">
                {productsData.slice(0, 4).map((p) => (
                  <div key={p.id} className="bg-white border border-amber-100 rounded-2xl p-4 flex items-center justify-between gap-3 shadow-xs hover:border-amber-400 transition-colors">
                    <div className="flex items-center gap-2.5 overflow-hidden">
                      <img src={p.image} className="w-10 h-10 object-cover rounded-lg flex-shrink-0" alt={p.name} />
                      <div className="overflow-hidden">
                        <p className="text-xs font-bold text-zinc-800 truncate">{p.name}</p>
                        <p className="text-xs text-amber-600 font-semibold mt-0.5">₹{p.price}</p>
                      </div>
                    </div>
                    <button onClick={() => handleAddToCart(p)} className="bg-amber-500 hover:bg-amber-400 text-zinc-900 w-8 h-8 rounded-full flex items-center justify-center font-bold flex-shrink-0 transition-transform hover:scale-105">
                      <Plus className="w-4 h-4" />
                    </button>
                  </div>
                ))}
              </div>
            </div>

            {/* Catalog Grid */}
            <section className="mb-12">
              <div className="flex items-center justify-between mb-6">
                <h2 className="text-2xl font-bold tracking-tight text-zinc-800">
                  {selectedCategory ? `${selectedCategory} Collection` : 'Neighborhood Favorites'}
                </h2>
                <span className="text-xs font-bold text-zinc-400 uppercase tracking-widest">{filteredProducts.length} items available</span>
              </div>

              {filteredProducts.length === 0 ? (
                <div className="text-center py-12 text-zinc-400">
                  No items matches your filter criteria.
                </div>
              ) : (
                <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-6">
                  {filteredProducts.map((p) => (
                    <div key={p.id} className="bg-white border border-neutral-200 rounded-3xl overflow-hidden shadow-xs hover:shadow-md transition-shadow group flex flex-col justify-between">
                      <div className="relative overflow-hidden aspect-square bg-zinc-100">
                        <img src={p.image} className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300" alt={p.name} />
                        <span className="absolute top-3 left-3 bg-zinc-900/80 backdrop-blur-xs text-white text-[10px] font-bold uppercase tracking-wider px-2.5 py-1 rounded-full">{p.category}</span>
                      </div>
                      <div className="p-5 flex-1 flex flex-col justify-between">
                        <div>
                          <h3 className="font-bold text-zinc-800 text-sm leading-snug group-hover:text-amber-600 transition-colors line-clamp-2">{p.name}</h3>
                          <div className="flex items-center gap-1 mt-2 mb-3">
                            <div className="flex text-amber-500">
                              {Array.from({ length: 5 }).map((_, i) => (
                                <Star key={i} className={`w-3.5 h-3.5 ${i < Math.floor(p.rating) ? 'fill-current' : ''}`} />
                              ))}
                            </div>
                            <span className="text-xs text-zinc-400 font-semibold">{p.rating}</span>
                          </div>
                        </div>
                        <div className="flex items-center justify-between pt-2 border-t border-neutral-100 mt-2">
                          <span className="text-lg font-bold text-zinc-800">₹{p.price}</span>
                          <button onClick={() => handleAddToCart(p)} className="bg-zinc-900 hover:bg-zinc-800 text-white text-xs font-bold px-3 py-2 rounded-xl transition-transform active:scale-95">Add to cart</button>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </section>
          </main>

          {/* Footer */}
          <footer className="bg-zinc-900 text-zinc-400 py-8 border-t border-zinc-800">
            <div className="max-w-7xl mx-auto px-4 text-center text-xs space-y-2">
              <p className="font-bold text-zinc-200">Rama Store - Samaur Bazar, Fazilnagar Road 274401</p>
              <p>Providing quality literature and school text registers to neighborhood desks since 1994.</p>
            </div>
          </footer>
        </>
      )}

      {view === 'login' && (
        <div className="relative">
          <button onClick={() => setView('home')} className="absolute top-6 left-6 z-50 flex items-center gap-2 text-xs font-bold text-zinc-600 hover:text-zinc-900 bg-white/80 backdrop-blur-xs px-3.5 py-2 rounded-xl shadow-xs border border-zinc-200 transition-all">
            <ArrowLeft className="w-4 h-4" />
            Back to Catalog
          </button>
          <SignInPage
            title={<span className="font-light tracking-tighter">Counter Sign In</span>}
            description="Log into the counter dashboard to manage checkout rewards points."
            testimonials={testimonialsData}
            onSignIn={handleSignIn}
            onGoogleSignIn={() => { setUser({ name: 'Google User', email: 'google@gmail.com' }); setView('home'); showToastMsg("Signed in with Google!"); }}
            onCreateAccount={() => setView('register')}
          />
        </div>
      )}

      {view === 'register' && (
        <div className="relative">
          <button onClick={() => setView('home')} className="absolute top-6 left-6 z-50 flex items-center gap-2 text-xs font-bold text-zinc-600 hover:text-zinc-900 bg-white/80 backdrop-blur-xs px-3.5 py-2 rounded-xl shadow-xs border border-zinc-200 transition-all">
            <ArrowLeft className="w-4 h-4" />
            Back to Catalog
          </button>
          <RegisterPage
            title={<span className="font-light tracking-tighter">Create Account</span>}
            description="Register a new customer profile for checkout discount rates."
            testimonials={testimonialsData}
            onRegister={handleRegister}
            onGoogleSignIn={() => { setUser({ name: 'Google User', email: 'google@gmail.com' }); setView('home'); showToastMsg("Registered with Google!"); }}
            onSignInRedirect={() => setView('login')}
          />
        </div>
      )}
    </div>
  );
}
