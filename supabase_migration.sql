-- 地球新主 (EarthLord) 数据库迁移脚本
-- 创建时间: 2025-12-26

-- =====================================================
-- 1. 创建 profiles 表（用户资料）
-- =====================================================
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE NOT NULL,
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- 为 profiles 表添加索引
CREATE INDEX IF NOT EXISTS idx_profiles_username ON public.profiles(username);

-- 启用 RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- RLS 策略：用户可以查看所有资料
CREATE POLICY "Profiles are viewable by everyone"
    ON public.profiles
    FOR SELECT
    USING (true);

-- RLS 策略：用户只能更新自己的资料
CREATE POLICY "Users can update own profile"
    ON public.profiles
    FOR UPDATE
    USING (auth.uid() = id);

-- RLS 策略：用户可以插入自己的资料
CREATE POLICY "Users can insert own profile"
    ON public.profiles
    FOR INSERT
    WITH CHECK (auth.uid() = id);

-- =====================================================
-- 2. 创建 territories 表（领地）
-- =====================================================
CREATE TABLE IF NOT EXISTS public.territories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    path JSONB NOT NULL,
    area DOUBLE PRECISION NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- 为 territories 表添加索引
CREATE INDEX IF NOT EXISTS idx_territories_user_id ON public.territories(user_id);
CREATE INDEX IF NOT EXISTS idx_territories_created_at ON public.territories(created_at DESC);

-- 启用 RLS
ALTER TABLE public.territories ENABLE ROW LEVEL SECURITY;

-- RLS 策略：所有人可以查看领地
CREATE POLICY "Territories are viewable by everyone"
    ON public.territories
    FOR SELECT
    USING (true);

-- RLS 策略：用户只能创建自己的领地
CREATE POLICY "Users can insert own territories"
    ON public.territories
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- RLS 策略：用户只能更新自己的领地
CREATE POLICY "Users can update own territories"
    ON public.territories
    FOR UPDATE
    USING (auth.uid() = user_id);

-- RLS 策略：用户只能删除自己的领地
CREATE POLICY "Users can delete own territories"
    ON public.territories
    FOR DELETE
    USING (auth.uid() = user_id);

-- =====================================================
-- 3. 创建 pois 表（兴趣点）
-- =====================================================
CREATE TABLE IF NOT EXISTS public.pois (
    id TEXT PRIMARY KEY,
    poi_type TEXT NOT NULL,
    name TEXT NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    discovered_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    discovered_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,

    -- 约束：经纬度范围
    CONSTRAINT valid_latitude CHECK (latitude >= -90 AND latitude <= 90),
    CONSTRAINT valid_longitude CHECK (longitude >= -180 AND longitude <= 180)
);

-- 为 pois 表添加索引
CREATE INDEX IF NOT EXISTS idx_pois_type ON public.pois(poi_type);
CREATE INDEX IF NOT EXISTS idx_pois_discovered_by ON public.pois(discovered_by);
CREATE INDEX IF NOT EXISTS idx_pois_location ON public.pois(latitude, longitude);

-- 启用 RLS
ALTER TABLE public.pois ENABLE ROW LEVEL SECURITY;

-- RLS 策略：所有人可以查看兴趣点
CREATE POLICY "POIs are viewable by everyone"
    ON public.pois
    FOR SELECT
    USING (true);

-- RLS 策略：已登录用户可以添加兴趣点
CREATE POLICY "Authenticated users can insert POIs"
    ON public.pois
    FOR INSERT
    WITH CHECK (auth.uid() IS NOT NULL);

-- RLS 策略：发现者可以更新自己发现的兴趣点
CREATE POLICY "Discoverers can update own POIs"
    ON public.pois
    FOR UPDATE
    USING (auth.uid() = discovered_by);

-- =====================================================
-- 4. 创建触发器函数：自动创建用户资料
-- =====================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, username, avatar_url)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'username', 'user_' || substring(NEW.id::text from 1 for 8)),
        NEW.raw_user_meta_data->>'avatar_url'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 创建触发器：用户注册时自动创建资料
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- =====================================================
-- 5. 创建视图：领地统计
-- =====================================================
CREATE OR REPLACE VIEW public.territory_stats AS
SELECT
    user_id,
    COUNT(*) as territory_count,
    SUM(area) as total_area,
    MAX(created_at) as last_territory_at
FROM public.territories
GROUP BY user_id;

-- =====================================================
-- 6. 创建视图：用户排行榜
-- =====================================================
CREATE OR REPLACE VIEW public.leaderboard AS
SELECT
    p.id,
    p.username,
    p.avatar_url,
    COALESCE(ts.territory_count, 0) as territory_count,
    COALESCE(ts.total_area, 0) as total_area,
    COUNT(DISTINCT poi.id) as pois_discovered
FROM public.profiles p
LEFT JOIN public.territory_stats ts ON p.id = ts.user_id
LEFT JOIN public.pois poi ON p.id = poi.discovered_by
GROUP BY p.id, p.username, p.avatar_url, ts.territory_count, ts.total_area
ORDER BY ts.total_area DESC NULLS LAST;

-- =====================================================
-- 完成提示
-- =====================================================
-- 迁移完成！已创建：
-- ✅ profiles 表（用户资料）
-- ✅ territories 表（领地）
-- ✅ pois 表（兴趣点）
-- ✅ RLS 策略
-- ✅ 自动创建用户资料的触发器
-- ✅ territory_stats 视图
-- ✅ leaderboard 排行榜视图
