import streamlit as st
from st_aggrid import AgGrid, GridOptionsBuilder, ColumnsAutoSizeMode
import pandas as pd

def render_listings_table(df: pd.DataFrame):
    if df.empty:
        st.warning("No listings found matching criteria.")
        return

    gb = GridOptionsBuilder.from_dataframe(df)
    gb.configure_pagination(paginationAutoPageSize=False, paginationPageSize=20)
    gb.configure_side_bar()
    gb.configure_selection('single', use_checkbox=True)
    gb.configure_column("url", headerName="URL", cellRenderer='''
        function(params) {
            return '<a href="' + params.value + '" target="_blank">🔗 View</a>'
        }
    ''')
    gb.configure_column("price", headerName="Price (TL)", type=["numericColumn", "numberColumnFilter"], valueFormatter="x.toLocaleString() + ' TL'")
    
    grid_options = gb.build()

    AgGrid(
        df,
        gridOptions=grid_options,
        columns_auto_size_mode=ColumnsAutoSizeMode.FIT_CONTENTS,
        theme='balham',  # Dark theme adjusted via streamlit custom css usually
        height=600,
        width='100%',
        allow_unsafe_jscode=True
    )
    
    col1, col2 = st.columns(2)
    with col1:
        st.download_button("📥 Export CSV", df.to_csv(index=False), "listings.csv", "text/csv")
    with col2:
        # Simplified JSON export for now
        st.download_button("📥 Export JSON", df.to_json(orient='records'), "listings.json", "application/json")
