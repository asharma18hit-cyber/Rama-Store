import React, { useState, useEffect } from 'react';
import {
  StyleSheet,
  Text,
  View,
  TextInput,
  TouchableOpacity,
  ScrollView,
  FlatList,
  ActivityIndicator,
  Modal,
  Alert,
  Dimensions,
  SafeAreaView,
  KeyboardAvoidingView,
  Platform,
} from 'react-native';
import {
  ShoppingBag,
  Package,
  TrendingUp,
  LogOut,
  Plus,
  Minus,
  Trash2,
  Edit,
  Search,
  Lock,
  User,
  Mail,
  Phone,
  FileText,
  CheckCircle,
  AlertTriangle,
  RefreshCw
} from 'lucide-react-native';
import client, { BASE_URL } from '../api/client';

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');

// Premium Slate Blue Color Palette
const COLORS = {
  background: '#0f172a', // Slate 900
  card: '#1e293b',       // Slate 800
  input: '#0f172a',      // Slate 900
  border: '#334155',     // Slate 700
  text: '#f8fafc',       // Slate 50
  textSecondary: '#94a3b8', // Slate 400
  primary: '#3b82f6',    // Blue 500
  primaryHover: '#2563eb', // Blue 600
  success: '#10b981',    // Emerald 500
  warning: '#f59e0b',    // Amber 500
  danger: '#ef4444',     // Red 500
};

export default function App() {
  const [user, setUser] = useState<any>(null);
  const [authChecking, setAuthChecking] = useState(true);
  const [currentTab, setCurrentTab] = useState<'store' | 'inventory' | 'dashboard'>('store');

  // Auth form states
  const [isRegister, setIsRegister] = useState(false);
  const [isForgot, setIsForgot] = useState(false);
  const [loginForm, setLoginForm] = useState({ emailOrPhone: '', password: '' });
  const [registerForm, setRegisterForm] = useState({ username: '', email: '', password: '' });
  const [forgotForm, setForgotForm] = useState({ emailOrPhone: '' });
  const [otpSent, setOtpSent] = useState(false);
  const [otpCode, setOtpCode] = useState('');
  const [pendingSession, setPendingSession] = useState<any>(null);
  const [newPassword, setNewPassword] = useState('');

  // Store/POS states
  const [products, setProducts] = useState<any[]>([]);
  const [categories, setCategories] = useState<any[]>([]);
  const [selectedCategory, setSelectedCategory] = useState<number | null>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [cart, setCart] = useState<any[]>([]);
  const [taxRate, setTaxRate] = useState('18.0');
  const [checkoutModalVisible, setCheckoutModalVisible] = useState(false);
  const [receipt, setReceipt] = useState<any>(null);
  const [customerAddress, setCustomerAddress] = useState('Default Store Delivery Address');
  const [paymentModalVisible, setPaymentModalVisible] = useState(false);
  const [pendingOrder, setPendingOrder] = useState<any>(null);
  const [cardForm, setCardForm] = useState({ cardNumber: '', expiry: '', cvv: '' });

  // Inventory states
  const [adminProducts, setAdminProducts] = useState<any[]>([]);
  const [productModalVisible, setProductModalVisible] = useState(false);
  const [editingProduct, setEditingProduct] = useState<any>(null);
  const [productForm, setProductForm] = useState({
    sku: '',
    name: '',
    categoryId: '',
    purchasePrice: '',
    sellingPrice: '',
    stock: '',
    status: 'published',
    imageUrl: ''
  });

  // Dashboard states
  const [metrics, setMetrics] = useState<any>(null);
  const [announcements, setAnnouncements] = useState<any>(null);

  // General Loading states
  const [loading, setLoading] = useState(false);
  const [refreshing, setRefreshing] = useState(false);

  useEffect(() => {
    checkAuthStatus();
  }, []);

  useEffect(() => {
    if (user) {
      loadStoreData();
      if (user.role === 'admin') {
        loadAdminData();
      }
    }
  }, [user]);

  const checkAuthStatus = async () => {
    try {
      const response = await client.get('/api/auth/status');
      if (response.data.authenticated) {
        setUser(response.data.user);
      } else {
        setUser(null);
      }
    } catch (error) {
      console.error('Auth check failed:', error);
      setUser(null);
    } finally {
      setAuthChecking(false);
    }
  };

  const loadStoreData = async () => {
    try {
      setLoading(true);
      const prodRes = await client.get('/api/store/products', {
        params: { page: 1, per_page: 50, search: searchQuery, category_id: selectedCategory }
      });
      setProducts(prodRes.data.products || []);

      const catRes = await client.get('/api/categories');
      setCategories(catRes.data || []);
    } catch (error) {
      console.error('Failed to load store data:', error);
      Alert.alert('Error', 'Failed to load products');
    } finally {
      setLoading(false);
    }
  };

  const loadAdminData = async () => {
    try {
      const prodRes = await client.get('/api/products', { params: { page: 1, per_page: 100 } });
      setAdminProducts(prodRes.data.products || []);

      const metricRes = await client.get('/api/dashboard/metrics');
      setMetrics(metricRes.data);

      const announceRes = await client.get('/api/announcements');
      setAnnouncements(announceRes.data);
    } catch (error) {
      console.error('Failed to load admin data:', error);
    }
  };

  const handleLogin = async () => {
    if (!loginForm.emailOrPhone || !loginForm.password) {
      Alert.alert('Missing Fields', 'Please enter your username/email and password.');
      return;
    }

    try {
      setLoading(true);
      // Attempt login
      const res = await client.post('/api/auth/login', {
        email_or_phone: loginForm.emailOrPhone,
        password: loginForm.password,
      });
      setUser(res.data.user);
      Alert.alert('Login Successful', `Welcome, ${res.data.user.fullname}!`);
    } catch (error: any) {
      const msg = error.response?.data?.error || 'Invalid credentials';
      // If it is admin, let's see if 2FA is needed
      if (loginForm.emailOrPhone === 'admin@ramastore.com' || loginForm.emailOrPhone === '7268903804') {
        // Owner 2FA trigger
        try {
          const otpRes = await client.post('/api/auth/admin-login-request', {
            email_or_phone: loginForm.emailOrPhone,
            password: loginForm.password,
          });
          setOtpSent(true);
          setPendingSession({ type: 'admin', emailOrPhone: loginForm.emailOrPhone, otp: otpRes.data.debug_otp });
          Alert.alert('2FA Verification Required', `Admin 2FA code sent (Debug: ${otpRes.data.debug_otp})`);
        } catch (e: any) {
          Alert.alert('Error', e.response?.data?.error || '2FA Request failed');
        }
      } else {
        Alert.alert('Login Failed', msg);
      }
    } finally {
      setLoading(false);
    }
  };

  const handleRegisterRequest = async () => {
    if (!registerForm.username || !registerForm.email || !registerForm.password) {
      Alert.alert('Missing Fields', 'All fields are required.');
      return;
    }

    try {
      setLoading(true);
      const res = await client.post('/api/auth/register', {
        username: registerForm.username,
        email: registerForm.email,
        password: registerForm.password,
      });
      setOtpSent(true);
      setPendingSession({ type: 'register', otp: res.data.debug_otp });
      Alert.alert('OTP Sent', `Verification OTP code sent (Debug: ${res.data.debug_otp})`);
    } catch (error: any) {
      Alert.alert('Registration Failed', error.response?.data?.error || 'Request failed');
    } finally {
      setLoading(false);
    }
  };

  const handleVerifyOtp = async () => {
    if (!otpCode) {
      Alert.alert('Error', 'Please enter the verification OTP.');
      return;
    }

    try {
      setLoading(true);
      if (pendingSession?.type === 'admin') {
        const res = await client.post('/api/auth/admin-login-verify', { otp: otpCode });
        setOtpSent(false);
        setPendingSession(null);
        setLoginForm({ emailOrPhone: '', password: '' });
        checkAuthStatus();
        Alert.alert('Authorized', 'Admin login successful!');
      } else if (pendingSession?.type === 'register') {
        const res = await client.post('/api/auth/verify_otp', { otp: otpCode });
        setOtpSent(false);
        setPendingSession(null);
        setRegisterForm({ username: '', email: '', password: '' });
        setUser(res.data.user);
        Alert.alert('Success', 'Account registered and logged in!');
      }
    } catch (error: any) {
      Alert.alert('Verification Failed', error.response?.data?.error || 'Invalid OTP');
    } finally {
      setLoading(false);
    }
  };

  const handleLogout = async () => {
    try {
      setLoading(true);
      await client.post('/api/auth/logout');
      setUser(null);
      setCart([]);
      setCurrentTab('store');
    } catch (error) {
      Alert.alert('Error', 'Logout failed');
    } finally {
      setLoading(false);
    }
  };

  // Cart operations
  const addToCart = (product: any) => {
    const existing = cart.find(item => item.id === product.id);
    if (existing) {
      if (existing.quantity >= product.stock) {
        Alert.alert('Limit Reached', 'Not enough stock available.');
        return;
      }
      setCart(cart.map(item => item.id === product.id ? { ...item, quantity: item.quantity + 1 } : item));
    } else {
      if (product.stock < 1) {
        Alert.alert('Out of Stock', 'This product is out of stock.');
        return;
      }
      setCart([...cart, { ...product, quantity: 1 }]);
    }
  };

  const updateCartQuantity = (productId: number, val: number) => {
    const item = cart.find(i => i.id === productId);
    if (!item) return;

    const newQty = item.quantity + val;
    if (newQty <= 0) {
      setCart(cart.filter(i => i.id !== productId));
    } else {
      const prod = products.find(p => p.id === productId) || adminProducts.find(p => p.id === productId);
      if (prod && newQty > prod.stock) {
        Alert.alert('Limit Reached', 'Not enough stock available.');
        return;
      }
      setCart(cart.map(i => i.id === productId ? { ...i, quantity: newQty } : i));
    }
  };

  const getCartTotals = () => {
    const subtotal = cart.reduce((sum, item) => sum + (item.selling_price * item.quantity), 0);
    const taxVal = parseFloat(taxRate) || 0;
    const tax = subtotal * (taxVal / 100);
    const total = subtotal + tax;
    return { subtotal, tax, total };
  };

  // Checkout flows
  const handleCheckoutSubmit = async () => {
    if (cart.length === 0) {
      Alert.alert('Empty Cart', 'Please add items to cart first.');
      return;
    }

    try {
      setLoading(true);
      const { subtotal } = getCartTotals();

      if (user.role === 'admin') {
        // Direct cash payment for POS
        const res = await client.post('/api/sales/complete', {
          cart: cart.map(i => ({ id: i.id, quantity: i.quantity })),
          tax_rate: parseFloat(taxRate)
        });
        setReceipt(res.data.receipt);
        setCart([]);
        setCheckoutModalVisible(false);
        loadStoreData();
        loadAdminData();
        Alert.alert('Success', 'POS Transaction Completed!');
      } else {
        // Customer flow: Create checkout session, then request payment
        const checkSession = await client.post('/api/checkout', {
          cart: cart.map(i => ({ id: i.id, quantity: i.quantity })),
          shipping_address: customerAddress
        });
        setPendingOrder(checkSession.data.session);
        setCheckoutModalVisible(false);
        setPaymentModalVisible(true);
      }
    } catch (error: any) {
      Alert.alert('Checkout Failed', error.response?.data?.error || 'Failed to checkout');
    } finally {
      setLoading(false);
    }
  };

  const handleProcessPayment = async () => {
    if (!cardForm.cardNumber || !cardForm.expiry || !cardForm.cvv) {
      Alert.alert('Missing Info', 'Please fill out card credentials.');
      return;
    }

    try {
      setLoading(true);
      const res = await client.post('/api/payment/process', {
        tracking_number: pendingOrder.tracking_number,
        card_number: cardForm.cardNumber,
        cvv: cardForm.cvv,
        expiry: cardForm.expiry
      });
      setPaymentModalVisible(false);
      setCart([]);
      loadStoreData();
      Alert.alert('Payment Successful', 'Order paid & scheduled for delivery!');
      setCardForm({ cardNumber: '', expiry: '', cvv: '' });
    } catch (error: any) {
      Alert.alert('Payment Declined', error.response?.data?.error || 'Transaction rolled back.');
    } finally {
      setLoading(false);
    }
  };

  // Inventory forms & CRUD
  const saveProduct = async () => {
    if (!productForm.sku || !productForm.name || !productForm.sellingPrice || !productForm.stock) {
      Alert.alert('Missing Info', 'SKU, Name, Selling Price, and Stock are required.');
      return;
    }

    const payload = {
      sku: productForm.sku,
      name: productForm.name,
      category_id: productForm.categoryId ? parseInt(productForm.categoryId) : null,
      purchase_price: parseFloat(productForm.purchasePrice) || 0,
      selling_price: parseFloat(productForm.sellingPrice) || 0,
      stock: parseInt(productForm.stock) || 0,
      status: productForm.status,
      image_url: productForm.imageUrl || null
    };

    try {
      setLoading(true);
      if (editingProduct) {
        // Edit existing
        await client.put(`/api/products/update/${editingProduct.id}`, payload);
        Alert.alert('Success', 'Product updated successfully.');
      } else {
        // Add new
        await client.post('/api/products', payload);
        Alert.alert('Success', 'Product added successfully.');
      }
      setProductModalVisible(false);
      setEditingProduct(null);
      setProductForm({ sku: '', name: '', categoryId: '', purchasePrice: '', sellingPrice: '', stock: '', status: 'published', imageUrl: '' });
      loadStoreData();
      loadAdminData();
    } catch (error: any) {
      Alert.alert('Failed to Save', error.response?.data?.error || 'Could not save product.');
    } finally {
      setLoading(false);
    }
  };

  const editProductPress = (prod: any) => {
    setEditingProduct(prod);
    setProductForm({
      sku: prod.sku,
      name: prod.name,
      categoryId: prod.category_id ? prod.category_id.toString() : '',
      purchasePrice: prod.purchase_price.toString(),
      sellingPrice: prod.selling_price.toString(),
      stock: prod.stock.toString(),
      status: prod.status,
      imageUrl: prod.image_url || ''
    });
    setProductModalVisible(true);
  };

  const deleteProductPress = (productId: number) => {
    Alert.alert('Confirm Delete', 'Are you sure you want to delete this product?', [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Delete',
        style: 'destructive',
        onPress: async () => {
          try {
            setLoading(true);
            await client.delete(`/api/products/delete/${productId}`);
            loadStoreData();
            loadAdminData();
            Alert.alert('Deleted', 'Product deleted successfully.');
          } catch (e: any) {
            Alert.alert('Failed to delete', e.response?.data?.error || 'Action failed.');
          } finally {
            setLoading(false);
          }
        }
      }
    ]);
  };

  // Rendering Helper views
  if (authChecking) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color={COLORS.primary} />
        <Text style={styles.loadingText}>Loading Rama Store...</Text>
      </View>
    );
  }

  if (!user) {
    return (
      <SafeAreaView style={styles.safeContainer}>
        <KeyboardAvoidingView
          behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
          style={styles.keyboardContainer}
        >
          <ScrollView contentContainerStyle={styles.authScrollContainer}>
            <View style={styles.headerTitleBox}>
              <ShoppingBag size={48} color={COLORS.primary} />
              <Text style={styles.mainTitle}>RAMA STORE</Text>
              <Text style={styles.subtitle}>Retail Management & POS Platform</Text>
            </View>

            <View style={styles.authCard}>
              <Text style={styles.authTitle}>
                {isForgot ? 'Forgot Password' : isRegister ? 'Create Account' : 'Sign In'}
              </Text>

              {otpSent ? (
                // OTP code input
                <View>
                  <Text style={styles.label}>Enter Verification OTP Code</Text>
                  <View style={styles.inputContainer}>
                    <Lock size={20} color={COLORS.textSecondary} />
                    <TextInput
                      style={styles.input}
                      placeholder="6-digit OTP code"
                      placeholderTextColor={COLORS.textSecondary}
                      keyboardType="number-pad"
                      value={otpCode}
                      onChangeText={setOtpCode}
                    />
                  </View>
                  <TouchableOpacity style={styles.button} onPress={handleVerifyOtp} disabled={loading}>
                    <Text style={styles.buttonText}>Verify & Login</Text>
                  </TouchableOpacity>
                  <TouchableOpacity style={styles.textBtn} onPress={() => setOtpSent(false)}>
                    <Text style={styles.textBtnText}>Back to Sign In</Text>
                  </TouchableOpacity>
                </View>
              ) : isForgot ? (
                // Forgot Password
                <View>
                  <Text style={styles.label}>Username or Email</Text>
                  <View style={styles.inputContainer}>
                    <Mail size={20} color={COLORS.textSecondary} />
                    <TextInput
                      style={styles.input}
                      placeholder="Enter registered credentials"
                      placeholderTextColor={COLORS.textSecondary}
                      value={forgotForm.emailOrPhone}
                      onChangeText={txt => setForgotForm({ ...forgotForm, emailOrPhone: txt })}
                    />
                  </View>
                  <TouchableOpacity style={styles.button} onPress={async () => {
                    if (!forgotForm.emailOrPhone) return;
                    try {
                      setLoading(true);
                      const res = await client.post('/api/auth/forgot-password', { email_or_phone: forgotForm.emailOrPhone });
                      setPendingSession({ type: 'forgot', emailOrPhone: forgotForm.emailOrPhone, otp: res.data.debug_otp });
                      setOtpSent(true);
                      Alert.alert('Code Sent', `OTP code for reset: ${res.data.debug_otp}`);
                    } catch (e: any) {
                      Alert.alert('Failed', e.response?.data?.error || 'Error sending code');
                    } finally {
                      setLoading(false);
                    }
                  }}>
                    <Text style={styles.buttonText}>Send Reset Code</Text>
                  </TouchableOpacity>
                  <TouchableOpacity style={styles.textBtn} onPress={() => setIsForgot(false)}>
                    <Text style={styles.textBtnText}>Back to Login</Text>
                  </TouchableOpacity>
                </View>
              ) : isRegister ? (
                // Register Form
                <View>
                  <Text style={styles.label}>Full Name / Shop Name</Text>
                  <View style={styles.inputContainer}>
                    <User size={20} color={COLORS.textSecondary} />
                    <TextInput
                      style={styles.input}
                      placeholder="Full Name"
                      placeholderTextColor={COLORS.textSecondary}
                      value={registerForm.username}
                      onChangeText={txt => setRegisterForm({ ...registerForm, username: txt })}
                    />
                  </View>

                  <Text style={styles.label}>Email Address / Phone Number</Text>
                  <View style={styles.inputContainer}>
                    <Mail size={20} color={COLORS.textSecondary} />
                    <TextInput
                      style={styles.input}
                      placeholder="Email or Phone Number"
                      placeholderTextColor={COLORS.textSecondary}
                      keyboardType="email-address"
                      value={registerForm.email}
                      onChangeText={txt => setRegisterForm({ ...registerForm, email: txt })}
                    />
                  </View>

                  <Text style={styles.label}>Password (Min 6 chars)</Text>
                  <View style={styles.inputContainer}>
                    <Lock size={20} color={COLORS.textSecondary} />
                    <TextInput
                      style={styles.input}
                      placeholder="Password"
                      placeholderTextColor={COLORS.textSecondary}
                      secureTextEntry
                      value={registerForm.password}
                      onChangeText={txt => setRegisterForm({ ...registerForm, password: txt })}
                    />
                  </View>

                  <TouchableOpacity style={styles.button} onPress={handleRegisterRequest} disabled={loading}>
                    <Text style={styles.buttonText}>Sign Up & Get OTP</Text>
                  </TouchableOpacity>

                  <TouchableOpacity style={styles.textBtn} onPress={() => setIsRegister(false)}>
                    <Text style={styles.textBtnText}>Already have an account? Sign In</Text>
                  </TouchableOpacity>
                </View>
              ) : (
                // Login Form
                <View>
                  <Text style={styles.label}>Email / Username</Text>
                  <View style={styles.inputContainer}>
                    <User size={20} color={COLORS.textSecondary} />
                    <TextInput
                      style={styles.input}
                      placeholder="Enter registered Email or Phone"
                      placeholderTextColor={COLORS.textSecondary}
                      autoCapitalize="none"
                      value={loginForm.emailOrPhone}
                      onChangeText={txt => setLoginForm({ ...loginForm, emailOrPhone: txt })}
                    />
                  </View>

                  <Text style={styles.label}>Password</Text>
                  <View style={styles.inputContainer}>
                    <Lock size={20} color={COLORS.textSecondary} />
                    <TextInput
                      style={styles.input}
                      placeholder="Password"
                      placeholderTextColor={COLORS.textSecondary}
                      secureTextEntry
                      value={loginForm.password}
                      onChangeText={txt => setLoginForm({ ...loginForm, password: txt })}
                    />
                  </View>

                  <TouchableOpacity style={styles.button} onPress={handleLogin} disabled={loading}>
                    <Text style={styles.buttonText}>Log In</Text>
                  </TouchableOpacity>

                  <View style={styles.authLinksBox}>
                    <TouchableOpacity style={styles.textBtn} onPress={() => setIsRegister(true)}>
                      <Text style={styles.textBtnText}>Create Account</Text>
                    </TouchableOpacity>
                    <TouchableOpacity style={styles.textBtn} onPress={() => setIsForgot(true)}>
                      <Text style={styles.textBtnText}>Forgot Password?</Text>
                    </TouchableOpacity>
                  </View>
                </View>
              )}
            </View>
          </ScrollView>
        </KeyboardAvoidingView>
      </SafeAreaView>
    );
  }

  // Authenticated Dashboard Layout
  return (
    <SafeAreaView style={styles.safeContainer}>
      <View style={styles.topHeader}>
        <View>
          <Text style={styles.headerStoreName}>Rama Store</Text>
          <Text style={styles.headerWelcome}>Hello, {user.fullname} ({user.role})</Text>
        </View>
        <TouchableOpacity style={styles.logoutBtn} onPress={handleLogout}>
          <LogOut size={20} color={COLORS.danger} />
        </TouchableOpacity>
      </View>

      {/* Main Tabs Container */}
      <View style={styles.mainContent}>
        {currentTab === 'store' && (
          <View style={styles.tabContent}>
            {/* SEARCH AND CATEGORY FILTER */}
            <View style={styles.filterBox}>
              <View style={styles.searchBar}>
                <Search size={18} color={COLORS.textSecondary} />
                <TextInput
                  style={styles.searchTextInput}
                  placeholder="Search products or SKUs..."
                  placeholderTextColor={COLORS.textSecondary}
                  value={searchQuery}
                  onChangeText={txt => {
                    setSearchQuery(txt);
                  }}
                  onSubmitEditing={loadStoreData}
                />
                {searchQuery !== '' && (
                  <TouchableOpacity onPress={() => { setSearchQuery(''); loadStoreData(); }}>
                    <Text style={styles.textBtnText}>Clear</Text>
                  </TouchableOpacity>
                )}
                <TouchableOpacity onPress={loadStoreData} style={styles.refreshBtnIcon}>
                  <RefreshCw size={16} color={COLORS.primary} />
                </TouchableOpacity>
              </View>

              {/* Categories Scroll */}
              <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.catScroll}>
                <TouchableOpacity
                  style={[styles.catBadge, selectedCategory === null && styles.catBadgeActive]}
                  onPress={() => { setSelectedCategory(null); loadStoreData(); }}
                >
                  <Text style={[styles.catBadgeText, selectedCategory === null && styles.catBadgeTextActive]}>All</Text>
                </TouchableOpacity>
                {categories.map(cat => (
                  <TouchableOpacity
                    key={cat.id}
                    style={[styles.catBadge, selectedCategory === cat.id && styles.catBadgeActive]}
                    onPress={() => { setSelectedCategory(cat.id); loadStoreData(); }}
                  >
                    <Text style={[styles.catBadgeText, selectedCategory === cat.id && styles.catBadgeTextActive]}>
                      {cat.name}
                    </Text>
                  </TouchableOpacity>
                ))}
              </ScrollView>
            </View>

            {/* PRODUCT LIST */}
            <FlatList
              data={products}
              keyExtractor={item => item.id.toString()}
              numColumns={2}
              columnWrapperStyle={styles.prodRow}
              renderItem={({ item }) => (
                <View style={styles.productCard}>
                  <View style={styles.prodCardHeader}>
                    {item.stock < 5 && (
                      <View style={styles.lowStockBadge}>
                        <Text style={styles.lowStockText}>Low Stock ({item.stock})</Text>
                      </View>
                    )}
                  </View>
                  <Text style={styles.prodName}>{item.name}</Text>
                  <Text style={styles.prodSku}>SKU: {item.sku}</Text>
                  <Text style={styles.prodPrice}>₹{item.selling_price.toFixed(2)}</Text>
                  <TouchableOpacity style={styles.addCartBtn} onPress={() => addToCart(item)}>
                    <Text style={styles.addCartText}>Add to Cart</Text>
                  </TouchableOpacity>
                </View>
              )}
              ListEmptyComponent={
                <View style={styles.emptyContainer}>
                  <Package size={48} color={COLORS.textSecondary} />
                  <Text style={styles.emptyText}>No products found.</Text>
                </View>
              }
            />

            {/* CART OVERLAY / BUTTON */}
            {cart.length > 0 && (
              <TouchableOpacity style={styles.cartOverlayBtn} onPress={() => setCheckoutModalVisible(true)}>
                <ShoppingBag size={20} color="#fff" />
                <Text style={styles.cartOverlayText}>
                  View Cart ({cart.reduce((sum, i) => sum + i.quantity, 0)} items) - ₹{getCartTotals().total.toFixed(2)}
                </Text>
              </TouchableOpacity>
            )}
          </View>
        )}

        {currentTab === 'inventory' && (
          <View style={styles.tabContent}>
            <View style={styles.tabActionHeader}>
              <Text style={styles.sectionTitle}>Inventory Catalog</Text>
              <TouchableOpacity
                style={styles.addProductBtn}
                onPress={() => {
                  setEditingProduct(null);
                  setProductForm({ sku: '', name: '', categoryId: '', purchasePrice: '', sellingPrice: '', stock: '', status: 'published', imageUrl: '' });
                  setProductModalVisible(true);
                }}
              >
                <Plus size={16} color="#fff" />
                <Text style={styles.addProductText}>Add Product</Text>
              </TouchableOpacity>
            </View>

            <FlatList
              data={adminProducts}
              keyExtractor={item => item.id.toString()}
              renderItem={({ item }) => (
                <View style={styles.inventoryItemCard}>
                  <View style={styles.inventoryDetails}>
                    <Text style={styles.invName}>{item.name}</Text>
                    <Text style={styles.invSku}>SKU: {item.sku} | Category ID: {item.category_id || 'None'}</Text>
                    <View style={styles.invPricesRow}>
                      <Text style={styles.invPriceLabel}>Cost: ₹{item.purchase_price}</Text>
                      <Text style={styles.invPriceLabel}>Sell: ₹{item.selling_price}</Text>
                    </View>
                    <View style={styles.invStockRow}>
                      <Text style={[styles.invStockText, item.stock < 5 && { color: COLORS.danger }]}>
                        Stock: {item.stock} units
                      </Text>
                      <Text style={styles.invStatusText}>Status: {item.status}</Text>
                    </View>
                  </View>
                  <View style={styles.inventoryActions}>
                    <TouchableOpacity style={styles.actionIconBtn} onPress={() => editProductPress(item)}>
                      <Edit size={16} color={COLORS.primary} />
                    </TouchableOpacity>
                    <TouchableOpacity style={styles.actionIconBtn} onPress={() => deleteProductPress(item.id)}>
                      <Trash2 size={16} color={COLORS.danger} />
                    </TouchableOpacity>
                  </View>
                </View>
              )}
            />
          </View>
        )}

        {currentTab === 'dashboard' && (
          <ScrollView style={styles.tabContent}>
            <Text style={styles.sectionTitle}>Store Dashboard</Text>
            
            {metrics ? (
              <View style={styles.metricsGrid}>
                <View style={styles.metricCard}>
                  <TrendingUp size={24} color={COLORS.primary} />
                  <Text style={styles.metricLabel}>Total Sales Revenue</Text>
                  <Text style={styles.metricVal}>₹{metrics.total_revenue?.toFixed(2) || '0.00'}</Text>
                </View>
                <View style={styles.metricCard}>
                  <CheckCircle size={24} color={COLORS.success} />
                  <Text style={styles.metricLabel}>Total Net Profit</Text>
                  <Text style={styles.metricVal}>₹{metrics.total_profit?.toFixed(2) || '0.00'}</Text>
                </View>
                <View style={styles.metricCard}>
                  <Package size={24} color={COLORS.warning} />
                  <Text style={styles.metricLabel}>Products in Catalog</Text>
                  <Text style={styles.metricVal}>{metrics.total_products || '0'}</Text>
                </View>
                <View style={styles.metricCard}>
                  <AlertTriangle size={24} color={COLORS.danger} />
                  <Text style={styles.metricLabel}>Low Stock Alerts</Text>
                  <Text style={[styles.metricVal, { color: COLORS.danger }]}>{metrics.low_stock_count || '0'}</Text>
                </View>
              </View>
            ) : (
              <ActivityIndicator size="small" color={COLORS.primary} />
            )}

            {announcements && (
              <View style={styles.announceCard}>
                <Text style={styles.announceTitle}>📢 Store Announcements</Text>
                <Text style={styles.announceText}>📦 Stock Status: {announcements.stock_status}</Text>
                <Text style={styles.announceText}>💳 Loyalty Offer: {announcements.loyalty_offer}</Text>
                <Text style={styles.announceText}>🚗 Delivery Services: {announcements.home_delivery}</Text>
              </View>
            )}
          </ScrollView>
        )}
      </View>

      {/* FOOTER TAB BAR BAR */}
      <View style={styles.footerTabBar}>
        <TouchableOpacity
          style={[styles.tabBarBtn, currentTab === 'store' && styles.tabBarBtnActive]}
          onPress={() => setCurrentTab('store')}
        >
          <ShoppingBag size={20} color={currentTab === 'store' ? COLORS.primary : COLORS.textSecondary} />
          <Text style={[styles.tabBarText, currentTab === 'store' && styles.tabBarTextActive]}>Store</Text>
        </TouchableOpacity>

        {user.role === 'admin' && (
          <>
            <TouchableOpacity
              style={[styles.tabBarBtn, currentTab === 'inventory' && styles.tabBarBtnActive]}
              onPress={() => setCurrentTab('inventory')}
            >
              <Package size={20} color={currentTab === 'inventory' ? COLORS.primary : COLORS.textSecondary} />
              <Text style={[styles.tabBarText, currentTab === 'inventory' && styles.tabBarTextActive]}>Inventory</Text>
            </TouchableOpacity>

            <TouchableOpacity
              style={[styles.tabBarBtn, currentTab === 'dashboard' && styles.tabBarBtnActive]}
              onPress={() => setCurrentTab('dashboard')}
            >
              <TrendingUp size={20} color={currentTab === 'dashboard' ? COLORS.primary : COLORS.textSecondary} />
              <Text style={[styles.tabBarText, currentTab === 'dashboard' && styles.tabBarTextActive]}>Dashboard</Text>
            </TouchableOpacity>
          </>
        )}
      </View>

      {/* CART / CHECKOUT MODAL */}
      <Modal visible={checkoutModalVisible} animationType="slide" transparent>
        <SafeAreaView style={styles.modalOverlay}>
          <View style={styles.modalContainer}>
            <View style={styles.modalHeader}>
              <Text style={styles.modalTitle}>Shopping Cart</Text>
              <TouchableOpacity onPress={() => setCheckoutModalVisible(false)}>
                <Text style={styles.modalCloseText}>Close</Text>
              </TouchableOpacity>
            </View>

            <FlatList
              data={cart}
              keyExtractor={item => item.id.toString()}
              renderItem={({ item }) => (
                <View style={styles.cartItemRow}>
                  <View style={{ flex: 1 }}>
                    <Text style={styles.cartItemName}>{item.name}</Text>
                    <Text style={styles.cartItemPrice}>₹{item.selling_price.toFixed(2)} each</Text>
                  </View>
                  <View style={styles.cartQtyControls}>
                    <TouchableOpacity style={styles.qtyBtn} onPress={() => updateCartQuantity(item.id, -1)}>
                      <Minus size={14} color={COLORS.text} />
                    </TouchableOpacity>
                    <Text style={styles.qtyVal}>{item.quantity}</Text>
                    <TouchableOpacity style={styles.qtyBtn} onPress={() => updateCartQuantity(item.id, 1)}>
                      <Plus size={14} color={COLORS.text} />
                    </TouchableOpacity>
                  </View>
                  <Text style={styles.cartItemTotal}>₹{(item.selling_price * item.quantity).toFixed(2)}</Text>
                </View>
              )}
              ListEmptyComponent={
                <View style={styles.emptyContainer}>
                  <Text style={styles.emptyText}>Your cart is empty.</Text>
                </View>
              }
            />

            {cart.length > 0 && (
              <View style={styles.checkoutSummaryBox}>
                <View style={styles.summaryRow}>
                  <Text style={styles.summaryLabel}>Subtotal</Text>
                  <Text style={styles.summaryValue}>₹{getCartTotals().subtotal.toFixed(2)}</Text>
                </View>
                <View style={styles.summaryRow}>
                  <Text style={styles.summaryLabel}>Tax Rate (%)</Text>
                  <TextInput
                    style={styles.taxInput}
                    keyboardType="numeric"
                    value={taxRate}
                    onChangeText={setTaxRate}
                  />
                </View>
                <View style={styles.summaryRow}>
                  <Text style={styles.summaryLabel}>Tax Amount</Text>
                  <Text style={styles.summaryValue}>₹{getCartTotals().tax.toFixed(2)}</Text>
                </View>
                <View style={[styles.summaryRow, { borderTopWidth: 1, borderTopColor: COLORS.border, paddingTop: 8 }]}>
                  <Text style={styles.summaryLabelBold}>Grand Total</Text>
                  <Text style={styles.summaryValueBold}>₹{getCartTotals().total.toFixed(2)}</Text>
                </View>

                {user.role !== 'admin' && (
                  <View style={{ marginTop: 12 }}>
                    <Text style={styles.label}>Shipping / Delivery Address</Text>
                    <TextInput
                      style={styles.modalTextInput}
                      placeholder="Shipping Address"
                      placeholderTextColor={COLORS.textSecondary}
                      value={customerAddress}
                      onChangeText={setCustomerAddress}
                    />
                  </View>
                )}

                <TouchableOpacity style={styles.checkoutConfirmBtn} onPress={handleCheckoutSubmit}>
                  <Text style={styles.checkoutConfirmText}>
                    {user.role === 'admin' ? 'Complete POS Cash Sale' : 'Proceed to Card Checkout'}
                  </Text>
                </TouchableOpacity>
              </View>
            )}
          </View>
        </SafeAreaView>
      </Modal>

      {/* MOCK GATEWAY PAYMENT MODAL */}
      <Modal visible={paymentModalVisible} animationType="fade" transparent>
        <View style={styles.modalOverlayCenter}>
          <View style={styles.paymentCard}>
            <Text style={styles.paymentTitle}>💳 Card Payment Gateway</Text>
            <Text style={styles.paymentSub}>Simulation Mode - Total: ₹{pendingOrder?.grand_total?.toFixed(2)}</Text>
            <Text style={styles.paymentSub}>Note: Testing cards ending in '4000' will decline.</Text>

            <Text style={styles.label}>16-Digit Card Number</Text>
            <TextInput
              style={styles.modalTextInput}
              placeholder="4000 1234 5678 9012"
              placeholderTextColor={COLORS.textSecondary}
              keyboardType="number-pad"
              maxLength={16}
              value={cardForm.cardNumber}
              onChangeText={txt => setCardForm({ ...cardForm, cardNumber: txt })}
            />

            <View style={{ flexDirection: 'row', gap: 12 }}>
              <View style={{ flex: 1 }}>
                <Text style={styles.label}>Expiry (MM/YY)</Text>
                <TextInput
                  style={styles.modalTextInput}
                  placeholder="12/29"
                  placeholderTextColor={COLORS.textSecondary}
                  maxLength={5}
                  value={cardForm.expiry}
                  onChangeText={txt => setCardForm({ ...cardForm, expiry: txt })}
                />
              </View>
              <View style={{ flex: 1 }}>
                <Text style={styles.label}>CVV</Text>
                <TextInput
                  style={styles.modalTextInput}
                  placeholder="123"
                  placeholderTextColor={COLORS.textSecondary}
                  keyboardType="number-pad"
                  maxLength={3}
                  secureTextEntry
                  value={cardForm.cvv}
                  onChangeText={txt => setCardForm({ ...cardForm, cvv: txt })}
                />
              </View>
            </View>

            <TouchableOpacity style={styles.button} onPress={handleProcessPayment}>
              <Text style={styles.buttonText}>Submit Payment</Text>
            </TouchableOpacity>

            <TouchableOpacity style={styles.textBtn} onPress={() => { setPaymentModalVisible(false); setPendingOrder(null); }}>
              <Text style={styles.textBtnText}>Cancel Order</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>

      {/* POS RECEIPT MODAL */}
      <Modal visible={!!receipt} animationType="fade" transparent>
        <View style={styles.modalOverlayCenter}>
          <View style={styles.receiptCard}>
            <View style={{ alignItems: 'center', marginBottom: 12 }}>
              <FileText size={32} color={COLORS.primary} />
              <Text style={styles.receiptTitle}>TRANSACTION RECEIPT</Text>
              <Text style={styles.receiptStore}>Rama Store POS</Text>
            </View>
            <ScrollView style={{ maxHeight: 200 }}>
              {receipt?.items?.map((item: any, idx: number) => (
                <View key={idx} style={styles.receiptItemRow}>
                  <Text style={styles.receiptItemText}>
                    {item.name} x {item.quantity}
                  </Text>
                  <Text style={styles.receiptItemPrice}>₹{item.total_selling_price}</Text>
                </View>
              ))}
            </ScrollView>
            <View style={styles.receiptDivider} />
            <View style={styles.summaryRow}>
              <Text style={styles.receiptSubText}>Subtotal</Text>
              <Text style={styles.receiptSubText}>₹{receipt?.subtotal}</Text>
            </View>
            <View style={styles.summaryRow}>
              <Text style={styles.receiptSubText}>Tax Amount</Text>
              <Text style={styles.receiptSubText}>₹{receipt?.tax_amount}</Text>
            </View>
            <View style={styles.summaryRow}>
              <Text style={styles.receiptTotalText}>GRAND TOTAL</Text>
              <Text style={styles.receiptTotalText}>₹{receipt?.grand_total}</Text>
            </View>
            <TouchableOpacity style={styles.button} onPress={() => setReceipt(null)}>
              <Text style={styles.buttonText}>Close Receipt</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>

      {/* ADD/EDIT INVENTORY PRODUCT MODAL */}
      <Modal visible={productModalVisible} animationType="slide" transparent>
        <SafeAreaView style={styles.modalOverlay}>
          <View style={styles.modalContainer}>
            <View style={styles.modalHeader}>
              <Text style={styles.modalTitle}>{editingProduct ? 'Edit Product' : 'Add New Product'}</Text>
              <TouchableOpacity onPress={() => setProductModalVisible(false)}>
                <Text style={styles.modalCloseText}>Cancel</Text>
              </TouchableOpacity>
            </View>

            <ScrollView contentContainerStyle={{ padding: 16 }}>
              <Text style={styles.label}>Product SKU Barcode *</Text>
              <TextInput
                style={styles.modalTextInput}
                placeholder="Unique SKU code"
                placeholderTextColor={COLORS.textSecondary}
                value={productForm.sku}
                onChangeText={txt => setProductForm({ ...productForm, sku: txt })}
              />

              <Text style={styles.label}>Product Name *</Text>
              <TextInput
                style={styles.modalTextInput}
                placeholder="Product Name"
                placeholderTextColor={COLORS.textSecondary}
                value={productForm.name}
                onChangeText={txt => setProductForm({ ...productForm, name: txt })}
              />

              <Text style={styles.label}>Category ID (Optional)</Text>
              <TextInput
                style={styles.modalTextInput}
                placeholder="Number (e.g. 1)"
                placeholderTextColor={COLORS.textSecondary}
                keyboardType="numeric"
                value={productForm.categoryId}
                onChangeText={txt => setProductForm({ ...productForm, categoryId: txt })}
              />

              <Text style={styles.label}>Purchase Price / Cost Price (₹)</Text>
              <TextInput
                style={styles.modalTextInput}
                placeholder="0.00"
                placeholderTextColor={COLORS.textSecondary}
                keyboardType="numeric"
                value={productForm.purchasePrice}
                onChangeText={txt => setProductForm({ ...productForm, purchasePrice: txt })}
              />

              <Text style={styles.label}>Selling Price (₹) *</Text>
              <TextInput
                style={styles.modalTextInput}
                placeholder="0.00"
                placeholderTextColor={COLORS.textSecondary}
                keyboardType="numeric"
                value={productForm.sellingPrice}
                onChangeText={txt => setProductForm({ ...productForm, sellingPrice: txt })}
              />

              <Text style={styles.label}>Stock Quantity *</Text>
              <TextInput
                style={styles.modalTextInput}
                placeholder="Available stock"
                placeholderTextColor={COLORS.textSecondary}
                keyboardType="numeric"
                value={productForm.stock}
                onChangeText={txt => setProductForm({ ...productForm, stock: txt })}
              />

              <Text style={styles.label}>Visibility Status</Text>
              <View style={{ flexDirection: 'row', gap: 12, marginBottom: 16 }}>
                <TouchableOpacity
                  style={[styles.statusToggleBtn, productForm.status === 'published' && styles.statusToggleActive]}
                  onPress={() => setProductForm({ ...productForm, status: 'published' })}
                >
                  <Text style={styles.statusToggleText}>Published</Text>
                </TouchableOpacity>
                <TouchableOpacity
                  style={[styles.statusToggleBtn, productForm.status === 'draft' && styles.statusToggleActive]}
                  onPress={() => setProductForm({ ...productForm, status: 'draft' })}
                >
                  <Text style={styles.statusToggleText}>Draft</Text>
                </TouchableOpacity>
              </View>

              <TouchableOpacity style={styles.button} onPress={saveProduct}>
                <Text style={styles.buttonText}>{editingProduct ? 'Save Product Changes' : 'Create Product'}</Text>
              </TouchableOpacity>
            </ScrollView>
          </View>
        </SafeAreaView>
      </Modal>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  loadingContainer: {
    flex: 1,
    backgroundColor: COLORS.background,
    justifyContent: 'center',
    alignItems: 'center',
  },
  loadingText: {
    marginTop: 12,
    color: COLORS.textSecondary,
    fontSize: 16,
  },
  safeContainer: {
    flex: 1,
    backgroundColor: COLORS.background,
  },
  keyboardContainer: {
    flex: 1,
  },
  authScrollContainer: {
    flexGrow: 1,
    justifyContent: 'center',
    padding: 24,
  },
  headerTitleBox: {
    alignItems: 'center',
    marginBottom: 32,
  },
  mainTitle: {
    fontSize: 32,
    fontWeight: 'bold',
    color: COLORS.text,
    marginTop: 12,
    letterSpacing: 2,
  },
  subtitle: {
    fontSize: 14,
    color: COLORS.textSecondary,
    marginTop: 4,
  },
  authCard: {
    backgroundColor: COLORS.card,
    borderRadius: 16,
    padding: 24,
    borderWidth: 1,
    borderColor: COLORS.border,
  },
  authTitle: {
    fontSize: 22,
    fontWeight: 'bold',
    color: COLORS.text,
    marginBottom: 20,
    textAlign: 'center',
  },
  label: {
    color: COLORS.text,
    fontSize: 13,
    marginBottom: 6,
    fontWeight: '600',
  },
  inputContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: COLORS.input,
    borderWidth: 1,
    borderColor: COLORS.border,
    borderRadius: 10,
    paddingHorizontal: 12,
    height: 48,
    marginBottom: 16,
  },
  input: {
    flex: 1,
    color: COLORS.text,
    marginLeft: 10,
    fontSize: 15,
  },
  button: {
    backgroundColor: COLORS.primary,
    borderRadius: 10,
    height: 48,
    justifyContent: 'center',
    alignItems: 'center',
    marginTop: 10,
  },
  buttonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: 'bold',
  },
  authLinksBox: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginTop: 16,
  },
  textBtn: {
    alignItems: 'center',
    marginTop: 16,
  },
  textBtnText: {
    color: COLORS.primary,
    fontSize: 14,
    fontWeight: '600',
  },
  topHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingVertical: 16,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border,
    backgroundColor: COLORS.card,
  },
  headerStoreName: {
    fontSize: 20,
    fontWeight: 'bold',
    color: COLORS.text,
  },
  headerWelcome: {
    fontSize: 13,
    color: COLORS.textSecondary,
  },
  logoutBtn: {
    padding: 8,
    borderRadius: 8,
    backgroundColor: COLORS.background,
  },
  mainContent: {
    flex: 1,
  },
  tabContent: {
    flex: 1,
    padding: 16,
  },
  filterBox: {
    marginBottom: 16,
  },
  searchBar: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: COLORS.card,
    borderRadius: 10,
    paddingHorizontal: 12,
    height: 44,
    borderWidth: 1,
    borderColor: COLORS.border,
  },
  searchTextInput: {
    flex: 1,
    color: COLORS.text,
    marginLeft: 8,
  },
  refreshBtnIcon: {
    marginLeft: 12,
  },
  catScroll: {
    marginTop: 10,
    flexDirection: 'row',
  },
  catBadge: {
    paddingHorizontal: 14,
    paddingVertical: 6,
    borderRadius: 20,
    backgroundColor: COLORS.card,
    marginRight: 8,
    borderWidth: 1,
    borderColor: COLORS.border,
  },
  catBadgeActive: {
    backgroundColor: COLORS.primary,
    borderColor: COLORS.primary,
  },
  catBadgeText: {
    color: COLORS.textSecondary,
    fontSize: 13,
  },
  catBadgeTextActive: {
    color: '#fff',
    fontWeight: 'bold',
  },
  prodRow: {
    justifyContent: 'space-between',
    marginBottom: 12,
  },
  productCard: {
    width: (SCREEN_WIDTH - 44) / 2,
    backgroundColor: COLORS.card,
    borderRadius: 12,
    padding: 12,
    borderWidth: 1,
    borderColor: COLORS.border,
  },
  prodCardHeader: {
    height: 18,
    marginBottom: 4,
  },
  lowStockBadge: {
    backgroundColor: 'rgba(239, 68, 68, 0.1)',
    borderRadius: 4,
    paddingHorizontal: 6,
    paddingVertical: 2,
    alignSelf: 'flex-start',
  },
  lowStockText: {
    color: COLORS.danger,
    fontSize: 10,
    fontWeight: 'bold',
  },
  prodName: {
    fontSize: 15,
    fontWeight: 'bold',
    color: COLORS.text,
    marginBottom: 2,
  },
  prodSku: {
    fontSize: 11,
    color: COLORS.textSecondary,
    marginBottom: 8,
  },
  prodPrice: {
    fontSize: 16,
    fontWeight: 'bold',
    color: COLORS.primary,
    marginBottom: 10,
  },
  addCartBtn: {
    backgroundColor: COLORS.primary,
    borderRadius: 8,
    paddingVertical: 8,
    alignItems: 'center',
  },
  addCartText: {
    color: '#fff',
    fontSize: 13,
    fontWeight: 'bold',
  },
  cartOverlayBtn: {
    position: 'absolute',
    bottom: 16,
    left: 16,
    right: 16,
    backgroundColor: COLORS.success,
    borderRadius: 12,
    height: 52,
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    gap: 10,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 4,
    elevation: 6,
  },
  cartOverlayText: {
    color: '#fff',
    fontSize: 15,
    fontWeight: 'bold',
  },
  emptyContainer: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 64,
  },
  emptyText: {
    color: COLORS.textSecondary,
    marginTop: 12,
    fontSize: 15,
  },
  footerTabBar: {
    flexDirection: 'row',
    height: 56,
    borderTopWidth: 1,
    borderTopColor: COLORS.border,
    backgroundColor: COLORS.card,
  },
  tabBarBtn: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  tabBarBtnActive: {
    borderTopWidth: 2,
    borderTopColor: COLORS.primary,
  },
  tabBarText: {
    fontSize: 11,
    color: COLORS.textSecondary,
    marginTop: 4,
  },
  tabBarTextActive: {
    color: COLORS.primary,
    fontWeight: 'bold',
  },
  sectionTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    color: COLORS.text,
    marginBottom: 16,
  },
  tabActionHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 16,
  },
  addProductBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: COLORS.primary,
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 8,
    gap: 6,
  },
  addProductText: {
    color: '#fff',
    fontWeight: 'bold',
    fontSize: 13,
  },
  inventoryItemCard: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    backgroundColor: COLORS.card,
    borderRadius: 12,
    padding: 16,
    marginBottom: 10,
    borderWidth: 1,
    borderColor: COLORS.border,
  },
  inventoryDetails: {
    flex: 1,
  },
  invName: {
    fontSize: 16,
    fontWeight: 'bold',
    color: COLORS.text,
  },
  invSku: {
    fontSize: 12,
    color: COLORS.textSecondary,
    marginTop: 2,
  },
  invPricesRow: {
    flexDirection: 'row',
    gap: 16,
    marginTop: 6,
  },
  invPriceLabel: {
    fontSize: 13,
    color: COLORS.textSecondary,
  },
  invStockRow: {
    flexDirection: 'row',
    gap: 16,
    marginTop: 6,
  },
  invStockText: {
    fontSize: 13,
    fontWeight: 'bold',
    color: COLORS.success,
  },
  invStatusText: {
    fontSize: 13,
    color: COLORS.textSecondary,
  },
  inventoryActions: {
    flexDirection: 'row',
    gap: 8,
  },
  actionIconBtn: {
    padding: 8,
    backgroundColor: COLORS.background,
    borderRadius: 8,
  },
  metricsGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
    marginBottom: 20,
  },
  metricCard: {
    width: (SCREEN_WIDTH - 44) / 2,
    backgroundColor: COLORS.card,
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
    borderWidth: 1,
    borderColor: COLORS.border,
    alignItems: 'center',
  },
  metricLabel: {
    fontSize: 12,
    color: COLORS.textSecondary,
    marginTop: 8,
    textAlign: 'center',
  },
  metricVal: {
    fontSize: 18,
    fontWeight: 'bold',
    color: COLORS.text,
    marginTop: 4,
  },
  announceCard: {
    backgroundColor: COLORS.card,
    borderRadius: 12,
    padding: 16,
    borderWidth: 1,
    borderColor: COLORS.border,
    marginTop: 10,
  },
  announceTitle: {
    fontSize: 16,
    fontWeight: 'bold',
    color: COLORS.text,
    marginBottom: 10,
  },
  announceText: {
    fontSize: 14,
    color: COLORS.textSecondary,
    marginBottom: 8,
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(15, 23, 42, 0.8)',
    justifyContent: 'flex-end',
  },
  modalContainer: {
    backgroundColor: COLORS.card,
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    height: SCREEN_HEIGHT * 0.85,
    borderTopWidth: 1,
    borderTopColor: COLORS.border,
  },
  modalHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 16,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border,
  },
  modalTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: COLORS.text,
  },
  modalCloseText: {
    color: COLORS.danger,
    fontSize: 14,
    fontWeight: '600',
  },
  cartItemRow: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 16,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border,
  },
  cartItemName: {
    fontSize: 15,
    fontWeight: 'bold',
    color: COLORS.text,
  },
  cartItemPrice: {
    fontSize: 13,
    color: COLORS.textSecondary,
    marginTop: 2,
  },
  cartQtyControls: {
    flexDirection: 'row',
    alignItems: 'center',
    marginHorizontal: 16,
    borderWidth: 1,
    borderColor: COLORS.border,
    borderRadius: 8,
    overflow: 'hidden',
  },
  qtyBtn: {
    padding: 8,
    backgroundColor: COLORS.background,
  },
  qtyVal: {
    paddingHorizontal: 12,
    color: COLORS.text,
    fontWeight: 'bold',
  },
  cartItemTotal: {
    fontSize: 15,
    fontWeight: 'bold',
    color: COLORS.primary,
    width: 80,
    textAlign: 'right',
  },
  checkoutSummaryBox: {
    padding: 16,
    borderTopWidth: 1,
    borderTopColor: COLORS.border,
    backgroundColor: COLORS.background,
  },
  summaryRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  summaryLabel: {
    color: COLORS.textSecondary,
    fontSize: 14,
  },
  summaryValue: {
    color: COLORS.text,
    fontSize: 14,
    fontWeight: '600',
  },
  taxInput: {
    width: 60,
    height: 32,
    backgroundColor: COLORS.card,
    borderWidth: 1,
    borderColor: COLORS.border,
    borderRadius: 6,
    color: COLORS.text,
    textAlign: 'center',
    padding: 0,
  },
  summaryLabelBold: {
    color: COLORS.text,
    fontSize: 16,
    fontWeight: 'bold',
  },
  summaryValueBold: {
    color: COLORS.success,
    fontSize: 18,
    fontWeight: 'bold',
  },
  modalTextInput: {
    backgroundColor: COLORS.input,
    borderWidth: 1,
    borderColor: COLORS.border,
    borderRadius: 10,
    paddingHorizontal: 12,
    height: 44,
    color: COLORS.text,
    marginTop: 8,
    marginBottom: 16,
  },
  checkoutConfirmBtn: {
    backgroundColor: COLORS.success,
    borderRadius: 10,
    height: 48,
    justifyContent: 'center',
    alignItems: 'center',
    marginTop: 16,
  },
  checkoutConfirmText: {
    color: '#fff',
    fontSize: 15,
    fontWeight: 'bold',
  },
  modalOverlayCenter: {
    flex: 1,
    backgroundColor: 'rgba(15, 23, 42, 0.8)',
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
  },
  paymentCard: {
    width: '100%',
    maxWidth: 400,
    backgroundColor: COLORS.card,
    borderRadius: 16,
    padding: 24,
    borderWidth: 1,
    borderColor: COLORS.border,
  },
  paymentTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    color: COLORS.text,
    marginBottom: 4,
  },
  paymentSub: {
    fontSize: 13,
    color: COLORS.textSecondary,
    marginBottom: 12,
  },
  receiptCard: {
    width: '100%',
    maxWidth: 400,
    backgroundColor: '#fff',
    borderRadius: 16,
    padding: 24,
  },
  receiptTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#000',
    marginTop: 8,
  },
  receiptStore: {
    fontSize: 13,
    color: '#666',
  },
  receiptItemRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginVertical: 4,
  },
  receiptItemText: {
    color: '#333',
    fontSize: 14,
  },
  receiptItemPrice: {
    color: '#333',
    fontWeight: '600',
  },
  receiptDivider: {
    height: 1,
    backgroundColor: '#ddd',
    marginVertical: 12,
    borderStyle: 'dashed',
  },
  receiptSubText: {
    color: '#666',
    fontSize: 13,
  },
  receiptTotalText: {
    color: '#000',
    fontSize: 16,
    fontWeight: 'bold',
    marginTop: 4,
  },
  statusToggleBtn: {
    flex: 1,
    paddingVertical: 10,
    borderRadius: 8,
    backgroundColor: COLORS.background,
    borderWidth: 1,
    borderColor: COLORS.border,
    alignItems: 'center',
  },
  statusToggleActive: {
    backgroundColor: COLORS.primary,
    borderColor: COLORS.primary,
  },
  statusToggleText: {
    color: COLORS.text,
    fontWeight: 'bold',
    fontSize: 13,
  }
});
