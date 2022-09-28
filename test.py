#importing libraries
import matplotlib.pyplot as plt
import matplotlib.animation as animation

#creating a subplot
fig, ax1 = plt.subplots()

def animate(i):
    data = open('./stock.txt','r').read()
    print(data)
    lines = data.split('\n')

    x = []
    y_short_mean = []
    y_long_mean = []
    y_price = []

    for line in lines:
        data = line.split(',') # Delimiter is comma
        if len(data) == 2:
            x, y_short_mean, y_long_mean, y_price = data
            x.append(float(x))
            y_short_mean.append(float(y_short_mean))
            y_long_mean.append(float(y_long_mean))
            y_price.append(y_price)
            y_buy_signal.append(-1.0)
            y_sell_signal.append(-1.0)
        elif len(data) == 3:
            signal, x, y_short_mean, y_long_mean, y_price = data
            x.append(float(x))
            y_short_mean.append(float(y_short_mean))
            y_long_mean.append(float(y_long_mean))
            y_price.append(y_price)
            if signal == "buy":
                y_buy_signal.append(y_price)
                y_sell_signal.append(-1.0)
            elif signal == "sell":
                y_buy_signal.append(-1.0)
                y_sell_signal.append(y_price)


    ax1.clear()

    ax1.plot(x, y_short_mean, lw=2, c="m")
    ax1.plot(x, y_long_mean, lw=2, c="c")
    ax1.plot(x, y_price, lw=2, c="b")
    ax1.plot(x, y_short_mean, lw=2, c="b")
    ax1.scatter(xc, yc, s=20, c="g")

    plt.xlabel('Date')
    plt.ylabel('Price')
    plt.title('Live graph with matplotlib')
    plt.ylim([0, 10])

ani = animation.FuncAnimation(fig, animate, interval=1000)

plt.show()