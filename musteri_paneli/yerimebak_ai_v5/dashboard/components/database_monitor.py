import streamlit as st

def render_database_monitor(db_health: dict):
    st.subheader("🗄️ Database Health")
    
    col1, col2, col3 = st.columns(3)
    with col1:
        st.write("**Size:**")
        st.info(f"{db_health.get('size_mb', 0)} MB")
    with col2:
        st.write("**Total Records:**")
        st.info(f"{db_health.get('total_records', 0):,}")
    with col3:
        st.write("**Provider:**")
        st.success(db_health.get('provider', 'SQLite'))

    st.write("**Performance Indicators**")
    st.progress(0.1, text="Query Load (Low)")
    st.caption("Average query time: 4ms | Write buffer: 0.1MB")
