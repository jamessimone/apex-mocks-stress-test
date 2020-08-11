public abstract class AbstractCacheRepo implements Cache.CacheBuilder, ICachedRepo {
    @testVisible private static Object stubValues;

    public Object doLoad(String requiredBySalesforce) {
        if(stubValues != null) {
            return stubValues;
        }
        return this.populateCache();
    }

    protected abstract String getCacheKey();

    protected Object getFromCache() {
        return Cache.Org.get(
            this.getCacheBuilder(),
            this.getCacheKey()
        );
    }

    public void clearCache() {
        Cache.Org.remove(
            this.getCacheBuilder(),
            this.getCacheKey()
        );
    }

    public void updateCache(Object cachedItem) {
        Cache.Org.put(
            this.getCacheKey(),
            cachedItem
        );
    }

    protected abstract Object populateCache();

    //virtual to allow inner classes to override
    protected virtual Type getCacheBuilder() {
        //the well-known hack for extracting the name
        //of the current class at runtime
        String className = String.valueOf(this)
                .split(':')[0];
        return Type.forName(className);
    }
}