import { Link } from "react-router-dom"


export const Home = () => {
  return <div>
    <h1>Oxfordshire Acro Society</h1>
    <p>The home of Oxfordshire Acro Society</p>
    <p>There are jams in the winter at New marston scout hall, OX3 0EJ, 1500 - 1800 on Sundays, all welcome.</p>
    <p>Training sessions at Oxsrad, OX3 0NQ, 1900 - 2100 on Thursday, for members only.</p>
    <p>We run a token system, it's 1 token per jam/training. 1 token costs 5 GBP, 10 tokens cost 45 GBP and 20 tokens cost 90 GBP. Tokens are non refundable, expire after one year and can be transferred to other members.</p>
    <p>You can come to 3 sessions as a temporary member before you must become a full member, full membership to the 31st of October is 6 GBP. Please register <Link to="/register">here</Link>.</p>
  </div>
}