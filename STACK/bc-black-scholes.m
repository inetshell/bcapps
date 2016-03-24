(*

This really isn't worth the bounty, but it's too long for a comment.

Quoting
https://www.tradeking.com/education/options/option-greeks-explained#theta

<blockquote>
At-the-money options move at the square root of time. This means if a
one-month ATM option is trading for $1, then a two-month ATM option
would be trading for 1 x sqrt of 2 or $1.41. A three-month ATM option
would be trading for 1 x sqrt of 3 or $1.73.
</blockquote>

As you can see from this example, selling 3 1 month options over 3
months would be worth $3, whereas a single 3 month option would be
worth only $1.73.

Formula-wise, this means the price of an at money option expiring in
$t$ days is $k \sqrt{t}$ (for some value of $k$ that depends on the
volatility). So, the money you make per day is $\frac{k \sqrt{t}}{t}$
or $\frac{k}{\sqrt{t}}$. As t becomes smaller, this number becomes
larger.

Thus, to maximize your per-day income, sell options as frequently as possible.

Of course, this assumes the underlying's price doesn't change. As I
noted in the comments, per the rule of arbitrage, there is no
guaranteed way to make money: this method only works on the assumption
the underlying's price is relatively stable (ie, more stable than the
volatility would indicate).

Another source re theta decay as a square root:

http://www.optionseducation.org/strategies_advanced_concepts/advanced_concepts/understanding_option_greeks/theta.html






Consider an asset whose $\log (\text{p})$ (p = price) change in 1 day
is modeled as a normal distribution with mean 0 (we're ignoring the
risk free interest rate) and standard deviation $s$.

The value of an at-the-money option expiring the next day will be 0 if
the asset price drops. If $\log (\text{p})$ increases by $d$, we have:

$\log \left(p_{\text{new}}\right)=d+\log \left(p_{\text{old}}\right)$

so the option in-money value is:

$p_{\text{new}}-p_{\text{old}}=\left(e^d-1\right) p_{\text{old}}$

The "chance" this happens is the PDF of the normal distribution with
standard deviation $s$ evaluated at $d$:

$\frac{e^{-\frac{d^2}{2 s^2}}}{\sqrt{2 \pi } s}$

Thus, for a $\log (\text{p})$ increase of $d$, the contribution to the
expected value is:

$\frac{\left(e^d-1\right) e^{-\frac{d^2}{2 s^2}} p_{\text{old}}}{\sqrt{2 \pi }
s}$

Integrating the above over all positive d:



In[18]:= 
FullSimplify[Integrate[(Exp[d]-1)*Exp[-d^2/2/s^2]/Sqrt[2*Pi]/s*Subscrip
t[p,old], {d,0,Infinity}], s>0]                                                 


(* tweaking BlackScholes.m to avoid function name collision *)

norm[z_] = 1/2 + Erf[z/Sqrt[2]]/2

aux[p_,k_,sd_,r_,t_] = (Log[p/(k (1+r)^-t)]/(sd Sqrt[t])) + 1/2* sd Sqrt[t]

optionvalue[p_,k_,sd_,r_,t_] = p  norm[aux[p,k,sd,r,t]]-
                               k (1+r)^-t (norm[aux[p,k,sd,r,t]-sd Sqrt[t]])











TODO: not worth bounty, black-scholes