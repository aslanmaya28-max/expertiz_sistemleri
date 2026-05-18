import plotly.express as px
import plotly.graph_objects as go
import streamlit as st
import pandas as pd

def render_price_trend_chart(df: pd.DataFrame, title: str = "Price Trend Over Time"):
    if df.empty:
        st.info("No historical data available for this selection.")
        return

    # Assuming df has 'recorded_at' and 'price'
    df['recorded_at'] = pd.to_datetime(df['recorded_at'])
    
    fig = px.line(df, x='recorded_at', y='price', title=title,
                 labels={'price': 'Price (TL)', 'recorded_at': 'Date'},
                 template="plotly_dark")
    
    fig.update_traces(line_color='#00ffe0', line_width=3)
    fig.update_layout(
        plot_bgcolor='rgba(0,0,0,0)',
        paper_bgcolor='rgba(0,0,0,0)',
        font_color='white',
        xaxis_showgrid=False,
        yaxis_showgrid=True,
        yaxis_gridcolor='rgba(255,255,255,0.1)'
    )
    
    st.plotly_chart(fig, use_container_width=True)

def render_market_distribution(df: pd.DataFrame):
    if df.empty: return
    
    fig = px.histogram(df, x="price", nbins=30, title="Market Price Distribution",
                      template="plotly_dark", color_discrete_sequence=['#00ffe0'])
    
    st.plotly_chart(fig, use_container_width=True)
