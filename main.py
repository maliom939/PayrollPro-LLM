from langchain_code import get_few_shot_db_chain
from pygwalker_code import display_graph
import streamlit as st

from pygwalker.api.streamlit import StreamlitRenderer, init_streamlit_comm

st.set_page_config(
    page_title="PayrollPro LLM",
    page_icon=":money_with_wings:",
    layout="wide",
)
init_streamlit_comm()

st.title("PayrollPro LLM")

options = ('Question - Answer', 'Company Statistics', 'Employee Attedance and Pay')
option = st.selectbox(
    'What would you like to do?', 
    options,
    index=None,
    placeholder="Select operation to perform ...",
    )


if option == options[0]:
    question = st.text_input("Question: ")
    if question:
        chain = get_few_shot_db_chain()
        answer = chain.run(question)
        st.header("Answer: ")
        st.write(answer)

elif option == options[1] or option == options[2]:
    st.write(f"Selected {option}")
    renderer = display_graph(option)
    renderer.render_explore()