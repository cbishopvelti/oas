import { Link } from "react-router-dom"


export const Home = () => {
  return <div>
    <h1>Oxfordshire Acro Society</h1>
    <p>This is the virtual home of the Oxfordshire Acro Society.</p>
    <p>There are jams in the Winter season at New Marston Scout Hall, OX3 0EJ, 1500 - 1800 on Sundays, all welcome.</p>
    <p>If you are joining for the first time, please go to “register” in the menu and sign up. You can come to 3 sessions as a temporary member before you must become a full member, full membership for this season runs until the 31st of October and is 6 GBP. Please register <Link to="/register">here</Link></p>
    <p>There are training sessions at Oxsrad Sports Centre, OX3 0NQ, 1900 - 2100 on Thursdays, for members only.</p>
    <p>We run a token system. Participating in indoor jams and trainings cost 1 token per session. 1 token costs 5 GBP, 10 tokens cost 45 GBP and 20 tokens cost 90 GBP. Tokens are non refundable and expire after one year, but they can be transferred to other members.</p>
  </div>
}